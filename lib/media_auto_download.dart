import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

/// Per-account preferences on this device. Existing chats default to manual downloads.
class MediaAutoDownload extends ChangeNotifier {
  MediaAutoDownload({
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
    String Function()? account,
  }) : _read = read ?? ((key) => const FlutterSecureStorage().read(key: key)),
       _write =
           write ??
           ((key, value) =>
               const FlutterSecureStorage().write(key: key, value: value)),
       _account =
           account ??
           (() => Session.userId.isNotEmpty ? Session.userId : Session.email);
  static MediaAutoDownload instance = MediaAutoDownload();
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  final String Function() _account;
  String? _loadedFor, _loadingFor;
  Future<void>? _loading;
  Map<String, bool> _values = {};
  static const keys = ['autoPhotos', 'autoVideos', 'autoDocuments'];
  bool get photos => _loadedFor == _account() && _values['autoPhotos'] == true;
  bool get videos => _loadedFor == _account() && _values['autoVideos'] == true;
  bool get documents =>
      _loadedFor == _account() && _values['autoDocuments'] == true;
  Map<String, bool> get values => {
    'autoPhotos': photos,
    'autoVideos': videos,
    'autoDocuments': documents,
  };
  bool allows(String mime) => mime.startsWith('image/')
      ? photos
      : mime.startsWith('video/')
      ? videos
      : !mime.startsWith('audio/') && documents;
  Future<void> restore() {
    final account = _account();
    if (_loadedFor == account) return Future.value();
    if (_loadingFor == account && _loading != null) return _loading!;
    _loadingFor = account;
    return _loading = _restore(account);
  }

  Future<void> _restore(String account) async {
    var data = <String, dynamic>{};
    try {
      final raw = await _read('chat-media-auto-v1:$account');
      if (raw != null) data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    if (account != _account()) return;
    _values = {for (final key in keys) key: data[key] == true};
    _loadedFor = account;
    notifyListeners();
  }

  Future<void> save(Map<String, dynamic> values) async {
    final account = _account();
    final next = {for (final key in keys) key: values[key] == true};
    await _write('chat-media-auto-v1:$account', jsonEncode(next));
    if (account != _account()) return;
    _values = next;
    _loadedFor = account;
    notifyListeners();
  }
}
