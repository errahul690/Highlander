import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'otp_api.dart';
import 'realtime_client.dart';

/// Header artwork is downloaded at startup, never by individual page headers.
class HeaderIconsRepository extends ChangeNotifier with WidgetsBindingObserver {
  HeaderIconsRepository({
    http.Client? client,
    Future<Directory> Function()? directory,
  }) : _client = client ?? http.Client(),
       _directory = directory ?? _defaultDirectory;

  static HeaderIconsRepository instance = HeaderIconsRepository();
  static const keys = ['search', 'notifications', 'admin_chat'];
  final http.Client _client;
  final Future<Directory> Function() _directory;
  final _bytes = <String, Uint8List>{};
  final _visibility = <String, bool>{};
  Map<String, Map<String, String>> _saved = {};
  String? _etag;
  Future<void>? _pending;
  DateTime? _lastChecked;
  bool _refreshAgain = false, _started = false, _disposed = false;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  Uint8List? iconBytes(String key) => _bytes[key];
  bool isVisible(String key) => _visibility[key] != false;

  static Future<Directory> _defaultDirectory() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/header-icons',
  );

  Future<void> restore() async {
    try {
      final directory = await _directory();
      final data = jsonDecode(
        await File('${directory.path}/settings.json').readAsString(),
      );
      if (data is! Map ||
          data['baseUrl'] != OtpApi.apiBase ||
          data['icons'] is! Map) {
        return;
      }
      var complete = true;
      final visibility = data['visibility'];
      for (final key in keys) {
        _visibility[key] = visibility is Map ? visibility[key] != false : true;
      }
      for (final key in keys) {
        final entry = data['icons'][key];
        if (entry is! Map ||
            entry['url'] is! String ||
            entry['file'] is! String) {
          continue;
        }
        final name = entry['file'] as String;
        if (!RegExp('^$key-[0-9]+\\.img\$').hasMatch(name)) {
          complete = false;
          continue;
        }
        try {
          final bytes = await File('${directory.path}/$name').readAsBytes();
          await _validateImage(bytes);
          _bytes[key] = bytes;
          _saved[key] = {'url': entry['url'], 'file': name};
        } catch (_) {
          complete = false;
        }
      }
      _etag = complete && data['etag'] is String
          ? data['etag'] as String
          : null;
      if (!_disposed) notifyListeners();
    } catch (_) {
      /* First launch or invalid cache: use bundled icons. */
    }
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (['all', 'header_icons'].contains(event['resource'])) {
        unawaited(refresh(force: true));
      }
    });
  }

  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future.value();
    if (_pending != null) {
      if (force) _refreshAgain = true;
      return _pending!;
    }
    if (!force &&
        _lastChecked != null &&
        DateTime.now().difference(_lastChecked!) <
            const Duration(minutes: 15)) {
      return Future.value();
    }
    return _pending = _refresh().whenComplete(() {
      _pending = null;
      if (_refreshAgain && !_disposed) {
        _refreshAgain = false;
        unawaited(refresh(force: true));
      }
    });
  }

  Future<void> _refresh() async {
    try {
      final base = OtpApi.apiBase;
      final response = await _client
          .get(
            Uri.parse('$base/api/public/app-settings'),
            headers: {'If-None-Match': ?_etag},
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 304) {
        _lastChecked = DateTime.now();
        return;
      }
      if (response.statusCode != 200) return;
      final payload = jsonDecode(response.body);
      if (payload is! Map ||
          payload['success'] != true ||
          payload['header_icons'] is! Map) {
        return;
      }
      final icons = <String, dynamic>{
        'search': '', // Older servers do not expose a search icon yet.
        ...Map<String, dynamic>.from(payload['header_icons'] as Map),
      };
      if (keys.any((key) => icons[key] is! String)) return;
      final visibility = payload['header_icon_visibility'];
      final nextVisibility = {
        for (final key in keys)
          key: visibility is Map ? visibility[key] != false : true,
      };
      final directory = await _directory();
      await directory.create(recursive: true);
      final saved = Map<String, Map<String, String>>.from(_saved);
      final bytes = Map<String, Uint8List>.from(_bytes);
      var complete = true;
      await Future.wait(
        keys.map((key) async {
          final url = (icons[key] as String).trim();
          if (url.isEmpty) {
            saved.remove(key);
            bytes.remove(key);
            return;
          }
          if (_saved[key]?['url'] == url && _bytes[key] != null) return;
          if (!RegExp(
            r'^/uploads/[a-zA-Z0-9_-]+\.(png|jpe?g|gif|webp)$',
            caseSensitive: false,
          ).hasMatch(url)) {
            complete = false;
            return;
          }
          try {
            final image = await _client
                .get(Uri.parse(base).resolve(url))
                .timeout(const Duration(seconds: 4));
            if (image.statusCode != 200 ||
                image.bodyBytes.length > 2 * 1024 * 1024) {
              throw const FormatException('Invalid icon response');
            }
            await _validateImage(image.bodyBytes);
            final name = '$key-${DateTime.now().microsecondsSinceEpoch}.img';
            await File('${directory.path}/$name')
                .writeAsBytes(image.bodyBytes, flush: true);
            saved[key] = {'url': url, 'file': name};
            bytes[key] = image.bodyBytes;
          } catch (_) {
            complete = false;
          }
        }),
      );
      if (_disposed) return;
      final etag = complete ? response.headers['etag'] : null;
      final metadata = {
        'baseUrl': base,
        'etag': etag,
        'icons': saved,
        'visibility': nextVisibility,
      };
      final temporary = File('${directory.path}/settings.json.tmp');
      await temporary.writeAsString(jsonEncode(metadata), flush: true);
      await temporary.rename('${directory.path}/settings.json');
      _saved = saved;
      _visibility
        ..clear()
        ..addAll(nextVisibility);
      _bytes
        ..clear()
        ..addAll(bytes);
      _etag = etag;
      _lastChecked = complete ? DateTime.now() : null;
      notifyListeners();
    } catch (_) {
      /* Keep the last complete artwork while offline. */
    }
  }

  Future<void> _validateImage(Uint8List bytes) async {
    if (bytes.isEmpty) throw const FormatException('Empty icon');
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 96,
      targetHeight: 96,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh(force: true));
  }

  @override
  void dispose() {
    _disposed = true;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _client.close();
    super.dispose();
  }
}
