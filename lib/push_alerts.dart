import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'notification_router.dart';
import 'otp_api.dart';
import 'session.dart';

const messageChannelId = 'highlanders_messages';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushAlerts {
  static bool ready = false;
  static bool _starting = false;
  static bool _listenersAttached = false;

  static void listenForBackgroundMessages() {
    if ((!Platform.isAndroid && !Platform.isIOS) ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
  }

  static Future<void> start() async {
    if (ready ||
        _starting ||
        (!Platform.isAndroid && !Platform.isIOS) ||
        Session.token.isEmpty) {
      return;
    }
    _starting = true;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              messageChannelId,
              'Messages',
              description: 'New messages and alerts',
              importance: Importance.high,
            ),
          );
      if (!_listenersAttached) {
        FirebaseMessaging.onMessageOpenedApp.listen(_open);
        FirebaseMessaging.onMessage.listen(_foregroundMessage);
        // The server currently addresses registration tokens through multicast.
        // ignore: deprecated_member_use
        messaging.onTokenRefresh.listen(_register);
        _listenersAttached = true;
        final initial = await messaging.getInitialMessage();
        if (initial != null) _open(initial);
      }
      if (Platform.isIOS) {
        for (var attempt = 0; attempt < 10; attempt++) {
          if (await messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        if (await messaging.getAPNSToken() == null) return;
      }
      // Keep registration tokens compatible with the server's multicast API.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      ready = token != null;
    } catch (_) {
      ready = false;
    } finally {
      _starting = false;
    }
  }

  static Future<void> _foregroundMessage(RemoteMessage message) async {
    // iOS presents foreground notifications through Firebase's native delegate.
    if (!Platform.isAndroid || Session.token.isEmpty) return;
    final notification = message.notification;
    if (notification == null) return;
    await FlutterLocalNotificationsPlugin().show(
      id:
          (message.messageId ?? DateTime.now().toIso8601String()).hashCode &
          0x7fffffff,
      title: notification.title ?? 'Highlanders',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          messageChannelId,
          'Messages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['payload'] as String?,
    );
  }

  static void _open(RemoteMessage message) {
    NotificationRouter.handle(message.data['payload']);
  }

  static Future<void> _register(String token) async {
    if (Session.token.isEmpty || OtpApi.apiBase.isEmpty || token.isEmpty) {
      return;
    }
    try {
      await http
          .post(
            Uri.parse('${OtpApi.apiBase}/api/user/push-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Session.token}',
            },
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
