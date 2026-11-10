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

  static void listenForBackgroundMessages() {
    if (!Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
  }

  static Future<void> start() async {
    if (ready || !Platform.isAndroid || Session.token.isEmpty) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
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
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial);
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      messaging.onTokenRefresh.listen(_register);
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  static void _open(RemoteMessage message) {
    NotificationRouter.handle(message.data['payload']);
  }

  static Future<void> _register(String token) async {
    if (Session.token.isEmpty || OtpApi.apiBase.isEmpty || token.isEmpty) return;
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
