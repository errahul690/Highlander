import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'notification_router.dart';
import 'push_alerts.dart';
import 'otp_api.dart';
import 'session.dart';

const _messageChannel = 'highlanders_messages';

bool get _underTest => Platform.environment.containsKey('FLUTTER_TEST');

class MessageAlerts {
  static final _notes = FlutterLocalNotificationsPlugin();
  static bool _notesReady = false;
  static bool _foreground = true;
  static io.Socket? _socket;
  static String _token = '';
  static bool _launchHandled = false;

  static Future<void> start() async {
    if (_underTest || Session.token.isEmpty) return;
    await _clearOngoingNotification();
    _foreground = true;
    await _prepareNotes();
    await PushAlerts.start();
    _connect();
  }

  static void setForeground(bool foreground) {
    if (_underTest) return;
    _foreground = foreground;
    if (foreground) {
      _connect();
      unawaited(PushAlerts.start());
    }
  }

  static Future<void> stop() async {
    if (_underTest) return;
    _token = '';
    _socket?.dispose();
    _socket = null;
    await _clearOngoingNotification();
  }

  static Future<void> _clearOngoingNotification() async {
    if (!Platform.isAndroid) return;
    try {
      FlutterForegroundTask.initCommunicationPort();
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  static void _connect() {
    if (Session.token.isEmpty || OtpApi.apiBase.isEmpty) return;
    if (_socket != null && _token == Session.token) {
      _socket!.connect();
      return;
    }
    _socket?.dispose();
    _token = Session.token;
    final email = Session.email.toLowerCase();
    final socket = io.io(
      OtpApi.apiBase,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .enableForceNew()
          .build(),
    );
    socket.on('receiveMessage', (value) => _onMessage(value, email));
    final sessionToken = Session.token;
    socket.on('session:revoked', (_) => Session.invalidate(sessionToken));
    socket.on(
      'connect_error',
      (error) => Session.handleSocketError(error, sessionToken),
    );
    socket.on('notification:new', _onAlert);
    socket.connect();
    _socket = socket;
  }

  static void _onMessage(dynamic value, String email) {
    if (value is! Map) return;
    final sender = '${value['senderEmail'] ?? ''}'.toLowerCase();
    if (sender.isEmpty || sender == email) return;
    final name = '${value['senderName'] ?? ''}'.trim();
    final content = '${value['content'] ?? ''}'.trim();
    final preview = content.isNotEmpty
        ? content
        : '${value['image'] ?? ''}'.isNotEmpty ||
              '${value['attachmentType'] ?? ''}'.startsWith('image/')
        ? 'Sent a photo'
        : '${value['attachmentUrl'] ?? ''}'.isNotEmpty
        ? 'Sent an attachment'
        : 'Sent a message';
    final receiver = '${value['receiverEmail'] ?? ''}'.trim();
    final roomId = '${value['conversationId'] ?? ''}'.trim();
    _show(
      name.isEmpty ? 'New message' : name,
      preview,
      payload: jsonEncode({
        'kind': receiver.isEmpty && roomId.isNotEmpty ? 'room' : 'chat',
        'email': sender,
        'name': name.isEmpty ? 'New message' : name,
        'roomId': roomId,
        'roomKind': '${value['roomKind'] ?? 'groups'}',
      }),
    );
  }

  static void _onAlert(dynamic value) {
    if (value is! Map) return;
    if ('${value['type']}' == 'direct_message') return;
    final title = '${value['title'] ?? ''}'.trim();
    final body = '${value['body'] ?? ''}'.trim();
    if (title.isEmpty && body.isEmpty) return;
    final metadata = value['metadata'] is Map
        ? Map<String, dynamic>.from(value['metadata'] as Map)
        : <String, dynamic>{};
    final type = '${value['type'] ?? ''}';
    _show(
      title.isEmpty ? 'Highlanders' : title,
      body,
      payload: jsonEncode({
        'kind': type,
        'type': type,
        'title': title,
        'name': '${value['actorName'] ?? title}',
        'email': '${metadata['senderEmail'] ?? value['actorEmail'] ?? ''}',
        'senderName': '${value['actorName'] ?? ''}',
        'isCare': metadata['isCare'] == true,
        'roomId': '${metadata['groupId'] ?? ''}',
        'roomName': '${metadata['roomName'] ?? ''}',
        'roomKind': '${metadata['kind'] ?? 'groups'}',
        'postId': '${metadata['postId'] ?? ''}',
        'matchId': '${metadata['matchId'] ?? ''}',
        'pollId': '${metadata['pollId'] ?? ''}',
        'link': '${value['link'] ?? ''}',
      }),
    );
  }

  static Future<void> _prepareNotes() async {
    if (_notesReady) return;
    await _notes.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );
    if (!_launchHandled) {
      _launchHandled = true;
      final launch = await _notes.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        NotificationRouter.handle(launch?.notificationResponse?.payload);
      }
    }
    await _notes
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _notesReady = true;
  }

  static void _onTap(NotificationResponse response) {
    NotificationRouter.handle(response.payload);
  }

  static Future<void> _show(
    String title,
    String body, {
    String? payload,
  }) async {
    if (_foreground || PushAlerts.ready) return;
    final text = body.length > 180 ? '${body.substring(0, 177)}...' : body;
    try {
      await _prepareNotes();
      await _notes.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: text,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _messageChannel,
            'Messages',
            channelDescription: 'New messages and alerts',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }
}
