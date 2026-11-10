import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'otp_api.dart';
import 'realtime_client.dart';

class SupportHubRepository extends ChangeNotifier {
  SupportHubRepository({http.Client? client})
    : _client = client ?? http.Client() {
    RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'support-hub' || event['resource'] == 'all') {
        unawaited(load());
      }
    });
  }

  static const defaultName = 'Support Hub';
  static SupportHubRepository instance = SupportHubRepository();
  final http.Client _client;
  String name = defaultName;
  int _version = 0;

  Future<void> load() async {
    final version = ++_version;
    try {
      final response = await _client
          .get(Uri.parse('${OtpApi.apiBase}/api/public/app-settings'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || version != _version) return;
      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true) return;
      final next = data['support_hub_name'];
      if (next is String && next.trim().isNotEmpty && next.trim() != name) {
        name = next.trim();
        notifyListeners();
      }
    } catch (_) {
      // Keep the last name while offline.
    }
  }
}
