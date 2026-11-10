import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'otp_api.dart';

class SplashCache {
  SplashCache._();

  static final SplashCache instance = SplashCache._();
  static const _storage = FlutterSecureStorage();
  static const _settingsKey = 'cached_splash_settings';
  static const _etagKey = 'cached_splash_etag';

  DateTime? _lastCheckedAt;
  Future<Map<String, dynamic>?>? _pendingRefresh;
  Map<String, dynamic>? current;

  /// Prefer this launch's admin setting, with a bounded wait on slow networks.
  Future<Map<String, dynamic>?> forLaunch({
    http.Client? client,
    Duration budget = const Duration(milliseconds: 1500),
  }) async {
    final cached = current ?? await read();
    try {
      final fresh = await refresh(client: client, force: true).timeout(budget);
      return fresh ?? cached;
    } catch (_) {
      // The refresh can finish caching in the background after this deadline.
      return cached;
    }
  }

  Future<File> _settingsFile() async {
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}splash',
    );
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}settings.json');
  }

  Future<Map<String, dynamic>?> read() async {
    try {
      final file = await _settingsFile();
      String? cached;
      if (await file.exists()) {
        cached = await file.readAsString();
      } else {
        cached = await _storage.read(key: _settingsKey);
      }
      if (cached == null || cached.isEmpty) return null;
      final data = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      final localHtml = '${data['_local_html_path'] ?? ''}';
      if (localHtml.isNotEmpty &&
          File(localHtml).existsSync() &&
          (data['html_content'] == null ||
              (data['html_content'] as String).isEmpty)) {
        try {
          data['html_content'] = await File(localHtml).readAsString();
        } catch (_) {}
      }
      current = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> refresh({
    http.Client? client,
    bool force = false,
  }) {
    if (!force &&
        _lastCheckedAt != null &&
        DateTime.now().difference(_lastCheckedAt!) <
            const Duration(minutes: 15)) {
      return Future.value(null);
    }
    if (client != null) return _refresh(client: client);
    return _pendingRefresh ??= _refresh(client: client).whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<Map<String, dynamic>?> _refresh({http.Client? client}) async {
    _lastCheckedAt = DateTime.now();
    final requestClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      String? etag;
      if (client == null) {
        try {
          etag = await _storage.read(key: _etagKey);
        } catch (_) {}
      }
      final headers = {
        if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
      };

      final http.Response? response;
      if (client != null) {
        response = await requestClient
            .get(
              Uri.parse('${OtpApi.apiBase}/api/public/app-settings'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 4));
      } else {
        response = await _firstSettingsResponse(requestClient, headers);
      }

      if (response == null || response.statusCode == 304) return null;
      if (response.statusCode != 200) return null;

      final payload = Map<String, dynamic>.from(
        jsonDecode(response.body) as Map,
      );
      if (payload['splash'] is! Map) return null;
      if (client != null) {
        return Map<String, dynamic>.from(payload['splash'] as Map);
      }

      final previous = await read();
      var splash = Map<String, dynamic>.from(payload['splash'] as Map);
      if (previous?['url'] == splash['url'] &&
          previous?['_local_media_path'] is String &&
          File('${previous!['_local_media_path']}').existsSync()) {
        splash['_local_media_path'] = previous['_local_media_path'];
      }

      // If splash is HTML, cache it to a file so we don't exceed SecureStorage limits
      if (splash['type'] == 'html' &&
          splash['html_content'] is String &&
          (splash['html_content'] as String).isNotEmpty) {
        try {
          final directory = Directory(
            '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}splash',
          );
          await directory.create(recursive: true);
          final htmlFile = File(
            '${directory.path}${Platform.pathSeparator}active.html',
          );
          await htmlFile.writeAsString(
            splash['html_content'] as String,
            flush: true,
          );
          splash['_local_html_path'] = htmlFile.path;
        } catch (_) {}
      }

      final responseEtag = response.headers['etag'];
      await _writeSettings(splash, responseEtag);
      current = splash;
      unawaited(_cacheSplashMedia(splash, responseEtag));
      return splash;
    } catch (_) {
      return null;
    } finally {
      if (ownsClient) requestClient.close();
    }
  }

  Future<http.Response?> _firstSettingsResponse(
    http.Client client,
    Map<String, String> headers,
  ) {
    final bases = OtpApi.candidateBases;
    if (bases.isEmpty) return Future.value(null);
    final done = Completer<http.Response?>();
    var remaining = bases.length;
    for (final base in bases) {
      unawaited(() async {
        http.Response? accepted;
        try {
          final res = await client
              .get(
                Uri.parse('$base/api/public/app-settings'),
                headers: headers,
              )
              .timeout(const Duration(milliseconds: 1200));
          if (res.statusCode == 200 || res.statusCode == 304) accepted = res;
        } catch (_) {}
        if (accepted != null && !done.isCompleted) {
          OtpApi.apiBase = base;
          done.complete(accepted);
        }
        remaining--;
        if (remaining == 0 && !done.isCompleted) done.complete(null);
      }());
    }
    return done.future;
  }

  Future<void> _cacheSplashMedia(Map<String, dynamic> splash, String? etag) async {
    final localPath = await _cacheMedia(splash);
    if (localPath == null) return;
    splash['_local_media_path'] = localPath;
    await _writeSettings(splash, etag);
  }

  Future<void> _writeSettings(Map<String, dynamic> splash, String? etag) async {
    final fileCopy = Map<String, dynamic>.from(splash);
    if ('${fileCopy['html_content'] ?? ''}'.length > 5000) {
      fileCopy['html_content'] = '';
    }
    try {
      final file = await _settingsFile();
      await file.writeAsString(jsonEncode(fileCopy), flush: true);
    } catch (_) {}
    try {
      await _storage.write(key: _settingsKey, value: jsonEncode(fileCopy));
      if (etag != null && etag.isNotEmpty) {
        await _storage.write(key: _etagKey, value: etag);
      }
    } catch (_) {}
  }

  Future<String?> _cacheMedia(Map<String, dynamic> splash) async {
    final client = http.Client();
    try {
      return await _downloadMedia(splash, client);
    } finally {
      client.close();
    }
  }

  Future<String?> _downloadMedia(
    Map<String, dynamic> splash,
    http.Client client,
  ) async {
    final type = '${splash['type'] ?? ''}'.toLowerCase();
    final url = '${splash['url'] ?? ''}'.trim();
    if (!{'image', 'gif', 'video'}.contains(type) || url.isEmpty) return null;
    final existing = '${splash['_local_media_path'] ?? ''}';
    if (existing.isNotEmpty && File(existing).existsSync()) return existing;
    try {
      final uri = Uri.parse(OtpApi.apiBase).resolve(url);
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}splash',
      );
      await directory.create(recursive: true);
      final extension = type == 'video'
          ? '.mp4'
          : type == 'gif'
          ? '.gif'
          : '.img';
      final file = File(
        '${directory.path}${Platform.pathSeparator}active$extension',
      );
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(response.bodyBytes, flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
