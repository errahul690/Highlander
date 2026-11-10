import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'otp_api.dart';
import 'session.dart';
import 'community_api.dart';

/// The shell and chat list share one authenticated delivery connection.
class ChatUpdates with WidgetsBindingObserver {
  static ChatUpdates instance = ChatUpdates();
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  io.Socket? _socket;
  String? _token;
  int _listeners = 0;
  final unreadCount = ValueNotifier<int>(0);
  final unreadNotifications = ValueNotifier<int>(0);
  bool _countLoading = false, _countPending = false;
  bool _alertLoading = false, _alertPending = false;
  int _alertGeneration = 0;

  void acquire() {
    if (_listeners++ == 0) WidgetsBinding.instance.addObserver(this);
    _connect();
    refreshUnreadCount();
    refreshNotificationCount();
  }

  void _connect() {
    if (Session.token.isEmpty) return;
    if (_socket == null || _token != Session.token) {
      _socket?.dispose();
      _token = Session.token;
      _socket = io.io(
        OtpApi.apiBase,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': Session.token})
            .disableAutoConnect()
            .enableForceNew()
            .build(),
      );
      _socket!.on('receiveMessage', (_) => notifyChanged());
      final sessionToken = Session.token;
      _socket!.on('session:revoked', (_) => Session.invalidate(sessionToken));
      _socket!.on(
        'connect_error',
        (error) => Session.handleSocketError(error, sessionToken),
      );
      _socket!.on('blockStatusChanged', (_) => notifyChanged());
      _socket!.on('chatsRead', (_) => notifyChanged());
      _socket!.on('notification:new', (dynamic value) {
        if (value is Map && value['type'] == 'direct_message') return;
        refreshNotificationCount();
      });
      // Socket.IO does not replay messages missed while disconnected.
      _socket!.onConnect((_) => notifyChanged());
    }
    _socket!.connect();
  }

  void notifyChanged() {
    _changes.add(null);
    refreshUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    if (_listeners == 0 || Session.token.isEmpty) return;
    if (_countLoading) {
      _countPending = true;
      return;
    }
    _countLoading = true;
    final token = Session.token;
    try {
      do {
        _countPending = false;
        final result = await CommunityApi.instance.request(
          '/direct/unread-count',
        );
        if (_listeners > 0 &&
            Session.token == token &&
            result is Map &&
            result['count'] is num) {
          unreadCount.value = (result['count'] as num).toInt();
        }
      } while (_countPending && _listeners > 0 && Session.token == token);
    } catch (_) {
      /* Reconnect and message updates retry failed counts. */
    } finally {
      _countLoading = false;
    }
  }

  Future<void> refreshNotificationCount() async {
    if (_listeners == 0 || Session.token.isEmpty) return;
    if (_alertLoading) {
      _alertPending = true;
      return;
    }
    _alertLoading = true;
    final token = Session.token;
    try {
      do {
        _alertPending = false;
        final generation = _alertGeneration;
        final result = await CommunityApi.instance.request(
          '/notifications?limit=1',
        );
        if (_listeners > 0 &&
            Session.token == token &&
            generation == _alertGeneration &&
            result is Map &&
            result['unreadCount'] is num) {
          unreadNotifications.value = (result['unreadCount'] as num).toInt();
        }
      } while (_alertPending && _listeners > 0 && Session.token == token);
    } catch (_) {
      /* Reconnect and new alerts retry a failed count. */
    } finally {
      _alertLoading = false;
    }
  }

  void noteUnreadNotifications(int count) {
    _alertGeneration++;
    unreadNotifications.value = count < 0 ? 0 : count;
  }

  void release() {
    if (_listeners == 0 || --_listeners > 0) return;
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    _socket = null;
    _token = null;
    unreadCount.value = 0;
    unreadNotifications.value = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connect();
      notifyChanged();
      refreshNotificationCount();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _socket?.disconnect();
    }
  }
}
