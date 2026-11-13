import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'club_repository.dart';
import 'chat_media_storage.dart';
import 'media_cache.dart';
import 'gallery_cache.dart';
import 'session.dart';

/// Account-scoped image files in the app's private storage, shared by chat and replies.
class ChatMediaCache {
  ChatMediaCache({
    http.Client? client,
    GalleryCache? storage,
    String Function()? account,
  }) : _client = client ?? http.Client(),
       _storage =
           storage ??
           ChatMediaStorage(
             directory: () async => Directory(
               '${(await getApplicationSupportDirectory()).path}/chat-media',
             ),
           ),
       _account =
           account ??
           (() => Session.userId.isNotEmpty ? Session.userId : Session.email);

  static ChatMediaCache instance = ChatMediaCache();
  final http.Client _client;
  final GalleryCache _storage;
  final String Function() _account;
  final _displays = <String, ChatMediaDisplay>{};
  final _displayPending = <String, Future<ChatMediaDisplay?>>{};
  final _recent = <String, List<String>>{};
  Future<void>? _indexWrite;
  String get _indexKey => '${_account()}|recent-chat-previews-v1';
  ChatMediaDisplay? peekDisplay(String url) => _displays[_key(url)];

  Future<ChatMediaDisplay?> _savedDisplay(String url) async {
    final ready = peekDisplay(url);
    if (ready != null) return ready;
    final key = _key(url);
    final saved = await _storage.read('$key#display-v1');
    if (saved == null || saved.bytes.isEmpty) return null;
    final ratio = double.tryParse(saved.headers['aspect'] ?? '');
    if (ratio == null || !ratio.isFinite || ratio <= 0) return null;
    final current = peekDisplay(url);
    if (current != null) return current;
    final display = ChatMediaDisplay(
      saved.bytes,
      saved.headers['downloaded'] == 'true',
      ratio,
    );
    _displays[key] = display;
    return display;
  }

  Future<void> _rememberDisplay(
    String key,
    String account,
    String url,
    Uint8List bytes, {
    required bool downloaded,
  }) async {
    try {
      if (!downloaded && _displays[key]?.downloaded == true) return;
      final small = await createChatThumbnail(bytes);
      final buffer = await ui.ImmutableBuffer.fromUint8List(small);
      late double ratio;
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        ratio = descriptor.width / descriptor.height;
        descriptor.dispose();
      } finally {
        buffer.dispose();
      }
      if (!downloaded && _displays[key]?.downloaded == true) return;
      final display = ChatMediaDisplay(small, downloaded, ratio);
      _displays[key] = display;
      while (_displays.length > 64) {
        _displays.remove(_displays.keys.first);
      }
      final recent = _recent.putIfAbsent(account, () => []);
      recent.remove(url);
      recent.insert(0, url);
      if (recent.length > 12) recent.removeRange(12, recent.length);
      final indexKey = '$account|recent-chat-previews-v1';
      final data = Uint8List.fromList(utf8.encode(jsonEncode(recent)));
      _indexWrite = (_indexWrite ?? Future<void>.value())
          .then((_) async {
            final latest = _displays[key] ?? display;
            await _storage.write(
              '$key#display-v1',
              SavedGalleryResource(latest.bytes, {
                'downloaded': '${latest.downloaded}',
                'aspect': '${latest.aspectRatio}',
              }),
            );
            await _storage.write(
              indexKey,
              SavedGalleryResource(data, const {}),
            );
          })
          .catchError((Object _) {});
      await _indexWrite;
    } catch (_) {}
  }

  /// Local previews only: no full-photo reads and no network requests at startup.
  Future<void> restoreRecent() async {
    final account = _account();
    if (account.isEmpty) return;
    final saved = await _storage.read(_indexKey);
    if (saved == null || account != _account()) return;
    try {
      final urls = (jsonDecode(utf8.decode(saved.bytes)) as List)
          .whereType<String>()
          .take(12)
          .toList();
      _recent[account] = urls;
      await Future.wait(
        urls.map((url) async {
          final display = await _savedDisplay(url);
          if (display != null && account == _account()) {
            await warmImage(display.bytes);
          }
        }),
      );
    } catch (_) {}
  }

  /// Persisted ready-sized preview carries the downloaded flag and aspect ratio.
  Future<ChatMediaDisplay?> display(String url, {String thumbnail = ''}) {
    final ready = peekDisplay(url);
    if (ready != null) return Future.value(ready);
    final key = _key(url);
    return _displayPending[key] ??= _display(url, thumbnail).whenComplete(() {
      _displayPending.remove(key);
    });
  }

  Future<ChatMediaDisplay?> _display(String url, String thumbnail) async {
    final account = _account();
    final key = _key(url);
    final saved = await _savedDisplay(url);
    if (saved != null) return saved;
    final original = await cached(url);
    if (account != _account()) return null;
    if (original != null) {
      await _rememberDisplay(key, account, url, original, downloaded: true);
    } else if (thumbnail.isNotEmpty) {
      final bytes = await load(thumbnail, saveDisplay: false);
      if (account != _account() || bytes == null) return null;
      await _rememberDisplay(key, account, url, bytes, downloaded: false);
    }
    return _displays[key];
  }

  final _bytes = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List?>>{};
  final _queue = Queue<void Function()>();
  int _active = 0, _memoryBytes = 0;
  static const maximumMemoryBytes = 24 * 1024 * 1024;
  String _key(String url) => '${_account()}|${ClubRepository.mediaUrl(url)}';

  Uint8List? peek(String url) {
    final key = _key(url);
    final bytes = _bytes.remove(key);
    if (bytes != null) _bytes[key] = bytes;
    return bytes;
  }

  Future<Uint8List?> load(String url, {bool saveDisplay = true}) {
    if (url.isEmpty) return Future.value();
    final key = _key(url);
    final ready = peek(url);
    if (ready != null) {
      if (saveDisplay && _displays[key]?.downloaded != true) {
        return _rememberDisplay(
          key,
          key.substring(0, key.indexOf('|')),
          url,
          ready,
          downloaded: true,
        ).then((_) => ready);
      }
      return Future.value(ready);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    final done = Completer<Uint8List?>();
    _pending[key] = done.future;
    _queue.add(() async {
      try {
        done.complete(
          await _load(
            key,
            ClubRepository.mediaUrl(url),
            saveDisplay: saveDisplay,
          ),
        );
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
    while (_active < 3 && _queue.isNotEmpty) {
      _active++;
      _queue.removeFirst()();
    }
  }

  void _remember(String key, Uint8List bytes) {
    final previous = _bytes.remove(key);
    _memoryBytes += bytes.length - (previous?.length ?? 0);
    _bytes[key] = bytes;
    while (_memoryBytes > maximumMemoryBytes && _bytes.length > 1) {
      _memoryBytes -= _bytes.remove(_bytes.keys.first)!.length;
    }
  }

  Future<Uint8List?> _load(
    String key,
    String url, {
    bool saveDisplay = true,
  }) async {
    final saved = await _storage.read(key);
    if (saved != null && saved.bytes.isNotEmpty && await _valid(saved.bytes)) {
      _remember(key, saved.bytes);
      if (saveDisplay && _displays[key]?.downloaded != true) {
        await _rememberDisplay(
          key,
          key.substring(0, key.indexOf('|')),
          url,
          saved.bytes,
          downloaded: true,
        );
      }
      return saved.bytes;
    }
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      // Invalid/error responses must never become permanent image files.
      if (!await _valid(response.bodyBytes)) return null;
      _remember(key, response.bodyBytes);
      await _storage.write(
        key,
        SavedGalleryResource(response.bodyBytes, const {}),
      );
      if (saveDisplay) {
        await _rememberDisplay(
          key,
          key.substring(0, key.indexOf('|')),
          url,
          response.bodyBytes,
          downloaded: true,
        );
      }
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _valid(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final image = await ui.ImageDescriptor.encoded(buffer);
        image.dispose();
      } finally {
        buffer.dispose();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> seed(
    String url,
    Uint8List bytes, {
    bool saveDisplay = true,
  }) async {
    if (url.isEmpty || bytes.isEmpty) return;
    final key = _key(url);
    _remember(key, bytes);
    await _storage.write(key, SavedGalleryResource(bytes, const {}));
    if (saveDisplay) {
      await _rememberDisplay(
        key,
        key.substring(0, key.indexOf('|')),
        url,
        bytes,
        downloaded: true,
      );
    }
  }

  /// Reads a downloaded photo without starting a network request.
  Future<Uint8List?> cached(String url) async {
    if (url.isEmpty) return null;
    final ready = peek(url);
    if (ready != null) return ready;
    final account = _account();
    final key = _key(url);
    final saved = await _storage.read(key);
    if (_account() != account || saved == null || !await _valid(saved.bytes)) {
      return null;
    }
    _remember(key, saved.bytes);
    return saved.bytes;
  }

  /// Only previews auto-download. The original requires an explicit download tap.
  Future<Uint8List?> preview(String url, {String thumbnail = ''}) async {
    final account = _account();
    final original = await cached(url);
    if (original != null) return original;
    if (_account() != account || thumbnail.isEmpty) return null;
    return load(thumbnail, saveDisplay: false);
  }

  /// Latest visible photos first; never download a whole 100-message history at once.
  Future<void> prefetchMessages(List<Map<String, dynamic>> messages) async {
    final photos = <Map<String, dynamic>>[];
    final seen = <String>{};
    void add(Map<String, dynamic> message) {
      if (photos.length >= 8) return;
      final url = '${message['attachmentUrl'] ?? message['image'] ?? ''}';
      final type = '${message['attachmentType'] ?? ''}';
      if (url.isNotEmpty &&
          (type.startsWith('image/') || message['image'] != null) &&
          seen.add(url)) {
        photos.add(message);
      }
    }

    for (final message in messages.reversed) {
      add(message);
      if (message['replyTo'] is Map) {
        add(Map<String, dynamic>.from(message['replyTo'] as Map));
      }
      if (photos.length >= 8) break;
    }
    await Future.wait(
      photos.map(
        (message) => display(
          '${message['attachmentUrl'] ?? message['image']}',
          thumbnail: '${message['attachmentThumbnail'] ?? ''}',
        ),
      ),
    );
  }
}

class ChatMediaDisplay {
  const ChatMediaDisplay(this.bytes, this.downloaded, this.aspectRatio);
  final Uint8List bytes;
  final bool downloaded;
  final double aspectRatio;
}

/// Small upload preview, generated once on the sender's device.
Future<Uint8List> createChatThumbnail(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final largest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final ratio = largest > 320 ? 320 / largest : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * ratio).round().clamp(1, 320),
        targetHeight: (descriptor.height * ratio).round().clamp(1, 320),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          return (await frame.image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
