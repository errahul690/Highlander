import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Highlanders/core/network/realtime_client.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/shared/data/club_repository.dart';

/// Admin artwork takes priority; missing or failed images use the bundled banner.
class FriendsBanner extends StatefulWidget {
  const FriendsBanner({super.key, this.client});
  final http.Client? client;

  @override
  State<FriendsBanner> createState() => _FriendsBannerState();
}

class _FriendsBannerState extends State<FriendsBanner>
    with WidgetsBindingObserver {
  late final http.Client _client = widget.client ?? http.Client();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String _url = '';
  int _version = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (['all', 'friends-banner'].contains(event['resource'])) {
        unawaited(_load());
      }
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final version = ++_version;
    final base = OtpApi.apiBase;
    try {
      final response = await _client
          .get(Uri.parse('$base/api/public/app-settings'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true) return;
      final image = data['friends_banner_image'];
      final url = image is String && image.trim().isNotEmpty
          ? ClubRepository.mediaUrl(image.trim())
          : '';
      if (mounted && version == _version && base == OtpApi.apiBase) {
        setState(() => _url = url);
      }
    } catch (_) {
      // Keep the last banner or the bundled fallback if settings are unavailable.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/friends-connect-banner.png',
      fit: BoxFit.contain,
      semanticLabel: 'Connect with the Club Community',
    );
    return ClipRRect(
      key: const ValueKey('friends-connect-banner'),
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 2146 / 733,
        child: _url.isEmpty
            ? fallback
            : Image.network(
                _url,
                key: ValueKey(_url),
                fit: BoxFit.contain,
                semanticLabel: 'Connect with the Club Community',
                frameBuilder: (_, child, frame, synchronous) =>
                    synchronous || frame != null ? child : fallback,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
