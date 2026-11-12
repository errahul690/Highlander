import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/services.dart';

import 'otp_api.dart';
import 'push_alerts.dart';
import 'message_alerts.dart';
import 'feed_store.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'session.dart';
import 'club_repository.dart';
import 'match_card_cache.dart';
import 'realtime_client.dart';
import 'theme.dart';
import 'post_link_router.dart';

import 'screens/splash_screen.dart';
import 'bundled_splash.dart';
import 'grounds_repository.dart';
import 'header_icons_repository.dart';
import 'chat_background_repository.dart';
import 'explore_repository.dart';
import 'screens/swoofi_screen.dart';
import 'feed_startup.dart';

export 'post_link_router.dart' show postIdFromLink;

final appNavigatorKey = GlobalKey<NavigatorState>();
const _links = MethodChannel('highlanders/app_links');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PushAlerts.listenForBackgroundMessages();
  Session.onInvalidated = () {
    unawaited(MessageAlerts.stop());
    FeedStore.clear();
    OtpApi.instance.mobileVerificationToken = '';
    OtpApi.instance.emailVerificationToken = '';
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  };
  await OtpApi.loadEnvironment();
  final launchSplash = loadBundledSplash();
  FeedStartup.warmBanners();
  unawaited(FeedStartup.ready());
  final sessionReady = Session.restore();
  FeedStartup.warm(sessionReady);
  await HeaderIconsRepository.instance.restore();
  HeaderIconsRepository.instance.start();
  ChatBackgroundRepository.instance.start();
  unawaited(ChatBackgroundRepository.instance.load());
  final headerIconsReady = HeaderIconsRepository.instance.refresh(force: true);
  RealtimeClient.instance.connectPublic();
  await MatchCardCache.instance.restore();
  await ExploreRepository.instance.restore();
  await SwoofiRepository.instance.restore();
  final clubReady = ClubRepository.instance.load().then<void>((_) {});
  unawaited(ExploreRepository.instance.load());
  unawaited(SwoofiRepository.instance.load(force: true));
  final startupReady = Future.wait<void>([
    sessionReady,
    headerIconsReady.timeout(const Duration(seconds: 3), onTimeout: () {}),
    clubReady.timeout(const Duration(seconds: 4), onTimeout: () {}),
  ]);
  final selectedSplash = await launchSplash;
  await GroundsRepository.instance.restore();
  try {
    // Android and Flutter render the same bundled splash artwork.
    await const MethodChannel('highlanders/splash')
        .invokeMethod<void>('prepare', selectedSplash)
        .timeout(const Duration(milliseconds: 500));
  } catch (_) {
    // iOS and platforms without this channel render the same choice in Flutter.
  }
  runApp(
    HighlandersApp(sessionReady: startupReady, initialSplash: selectedSplash),
  );
  unawaited(GroundsRepository.instance.preload());
  _links.setMethodCallHandler((call) async {
    if (call.method == 'incomingLink' && call.arguments is String) {
      PostLinkRouter.handle(call.arguments as String);
    }
  });
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final initial = await _links.invokeMethod<String>('getInitialLink');
      if (initial != null) PostLinkRouter.handle(initial);
    } on MissingPluginException {
      // Platforms without the native link channel can still run the app.
    }
  });
}

class HighlandersApp extends StatelessWidget {
  const HighlandersApp({
    super.key,
    this.home,
    this.showSplash,
    this.sessionReady,
    this.initialSplash,
  });

  final Widget? home;
  final bool? showSplash;
  final Future<void>? sessionReady;
  final Map<String, dynamic>? initialSplash;

  Widget _destination() =>
      home ?? (Session.isSignedIn ? const AppShell() : const LoginScreen());

  @override
  Widget build(BuildContext context) {
    final isRunningInTest = WidgetsBinding.instance.runtimeType
        .toString()
        .toLowerCase()
        .contains('test');
    final displaySplash = showSplash ?? !isRunningInTest;

    return MaterialApp(
      title: 'Highlanders',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: clubTheme(),
      home: displaySplash
          ? SplashScreen(
              resolveNext: _destination,
              sessionReady: sessionReady,
              initialSplash: initialSplash,
            )
          : _destination(),
    );
  }
}
