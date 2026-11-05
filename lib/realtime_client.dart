import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'otp_api.dart';

// One app-wide connection for public updates. Widgets only subscribe to streams.
class RealtimeClient with WidgetsBindingObserver {
  static RealtimeClient instance = RealtimeClient();
  static const appSettingsUpdated = 'app-settings:updated';
  final _settings = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final List<Future<void>> _feedRefreshWork = [];
  Stream<Map<String, dynamic>> get settingsChanges => _settings.stream;

  void trackFeedRefresh(Future<void> work) => _feedRefreshWork.add(work);

  Future<void> refreshFeed() {
    _feedRefreshWork.clear();
    dispatchSettingsUpdate({'resource': 'feed-refresh', 'action': 'refresh'});
    final work = List<Future<void>>.from(_feedRefreshWork);
    _feedRefreshWork.clear();
    return work.isEmpty ? Future<void>.value() : Future.wait(work);
  }
  io.Socket? _publicSocket;

  void connectPublic() {
    if (_publicSocket != null) {
      _publicSocket!.connect();
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _publicSocket = io.io(
      '${OtpApi.apiBase}/public',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _publicSocket!.on(appSettingsUpdated, dispatchSettingsUpdate);
    // Reload after every reconnect: Socket.IO does not replay missed changes.
    _publicSocket!.onConnect(
      (_) => dispatchSettingsUpdate({'resource': 'all', 'action': 'reconnect'}),
    );
    _publicSocket!.connect();
  }

  void dispatchSettingsUpdate(dynamic data) {
    if (data is! Map ||
        ![
          'all',
          'buttons',
          'banners',
          'marquee',
          'poll',
          'posts',
          'explore',
          'header_icons',
          'chat-background',
          'matches',
          'feed-focus',
          'feed-refresh',
          'knockoutMatches',
        ].contains(data['resource'])) {
      return;
    }
    _settings.add(Map<String, dynamic>.from(data));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _publicSocket?.connect();
    if (state == AppLifecycleState.paused) _publicSocket?.disconnect();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _publicSocket?.dispose();
    _publicSocket = null;
    _settings.close();
  }
}
