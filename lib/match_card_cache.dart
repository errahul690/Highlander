import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'widgets/match_card_veil.dart';

/// Keeps the match-card photo and tint ready before a match screen opens.
class MatchCardCache {
  MatchCardCache({Future<Directory> Function()? directory, http.Client? client})
    : _directory = directory ?? _defaultDirectory,
      _client = client;

  static final MatchCardCache instance = MatchCardCache();

  final Future<Directory> Function() _directory;
  final http.Client? _client;

  static Future<Directory> _defaultDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}match-card');
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> restore() async {
    try {
      final directory = await _directory();
      final meta = await _read(directory);
      final name = '${meta['file'] ?? ''}';
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      if (name.isEmpty || !await file.exists() || await file.length() == 0) {
        if (meta.containsKey('overlay')) MatchCardOverlay.apply(meta['overlay'], localFile: '');
        return;
      }
      MatchCardOverlay.apply(meta['overlay'], localFile: file.path);
    } catch (_) {}
  }

  Future<void> sync({
    required Object? overlay,
    required String url,
    http.Client? client,
  }) async {
    final directory = await _directory();
    final meta = await _read(directory);
    final previousName = '${meta['file'] ?? ''}';
    final previous = File('${directory.path}${Platform.pathSeparator}$previousName');
    final previousReady =
        previousName.isNotEmpty && await previous.exists() && await previous.length() > 0;
    if (url.isEmpty) {
      MatchCardOverlay.apply(overlay, localFile: '');
      await _write(directory, {'overlay': _percent(overlay), 'url': '', 'file': ''});
      if (previousReady) await _delete(previous);
      return;
    }
    if (url == meta['url'] && previousReady) {
      MatchCardOverlay.apply(overlay, localFile: previous.path);
      await _write(directory, {'overlay': _percent(overlay), 'url': url, 'file': previousName});
      return;
    }
    final requestClient = client ?? _client ?? http.Client();
    final ownsClient = client == null && _client == null;
    try {
      final response = await requestClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        MatchCardOverlay.apply(overlay, localFile: previousReady ? previous.path : '');
        return;
      }
      final name = 'card-${DateTime.now().microsecondsSinceEpoch}.img';
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      MatchCardOverlay.apply(overlay, localFile: file.path);
      await _write(directory, {'overlay': _percent(overlay), 'url': url, 'file': name});
      if (previousReady && previous.path != file.path) await _delete(previous);
    } catch (_) {
      MatchCardOverlay.apply(overlay, localFile: previousReady ? previous.path : '');
    } finally {
      if (ownsClient) requestClient.close();
    }
  }

  Future<Map<String, dynamic>> _read(Directory directory) async {
    try {
      final file = File('${directory.path}${Platform.pathSeparator}card.json');
      if (!await file.exists()) return {};
      final data = jsonDecode(await file.readAsString());
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Directory directory, Map<String, Object?> data) async {
    final file = File('${directory.path}${Platform.pathSeparator}card.json');
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static double _percent(Object? raw) {
    final parsed = raw is num ? raw.toDouble() : double.tryParse('$raw');
    return (parsed ?? 8).clamp(0, 40).toDouble();
  }
}
