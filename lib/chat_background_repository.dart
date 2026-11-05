import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'otp_api.dart';
import 'realtime_client.dart';

class ChatBackgroundRepository extends ChangeNotifier {
  ChatBackgroundRepository({http.Client? client})
    : _client = client ?? http.Client();
  static ChatBackgroundRepository instance = ChatBackgroundRepository();
  static final _upload = RegExp(
    r'^/uploads/[a-zA-Z0-9_-]+\.(png|jpe?g|gif|webp|avif)$',
    caseSensitive: false,
  );
  final http.Client _client;
  String imageUrl = '';
  Uint8List? imageBytes;
  int _version = 0;
  bool _started = false;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  void start() {
    if (_started) return;
    _started = true;
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (['all', 'chat-background'].contains(event['resource'])) {
        unawaited(load());
      }
    });
  }

  Future<void> load() async {
    final version = ++_version;
    try {
      final base = OtpApi.apiBase;
      final response = await _client
          .get(
            Uri.parse('$base/api/public/app-settings'),
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 ||
          version != _version ||
          base != OtpApi.apiBase) {
        return;
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true) return;
      final path = data['chat_background_image'] ?? '';
      if (path is! String || (path.isNotEmpty && !_upload.hasMatch(path))) {
        return;
      }
      if (path.isEmpty) {
        imageUrl = '';
        imageBytes = null;
        notifyListeners();
        return;
      }
      final image = await _client
          .get(
            Uri.parse(base).resolve(path).replace(
              queryParameters: {
                'v': DateTime.now().microsecondsSinceEpoch.toString(),
              },
            ),
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 20));
      if (version != _version ||
          image.statusCode != 200 ||
          image.bodyBytes.isEmpty ||
          image.bodyBytes.length > 6 * 1024 * 1024) {
        return;
      }
      imageUrl = Uri.parse(base).resolve(path).toString();
      imageBytes = image.bodyBytes;
      notifyListeners();
    } catch (_) {
      // Retain the current background if settings cannot be loaded.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
