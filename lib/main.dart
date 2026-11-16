import 'package:flutter/material.dart';
import 'package:Highlanders/features/settings/widgets/store_update_gate.dart';

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/core/notifications/push_alerts.dart';
import 'package:Highlanders/core/notifications/message_alerts.dart';
import 'package:Highlanders/features/feed/data/feed_store.dart';
import 'package:Highlanders/features/settings/data/app_settings_repository.dart';
import 'package:Highlanders/features/auth/screens/login_screen.dart';
import 'package:Highlanders/app/shell.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/features/matches/data/match_card_cache.dart';
import 'package:Highlanders/core/network/realtime_client.dart';
import 'package:Highlanders/core/theme/theme.dart';
import 'package:Highlanders/features/posts/services/post_link_router.dart';

import 'package:Highlanders/features/splash/screens/splash_screen.dart';
import 'package:Highlanders/features/splash/data/bundled_splash.dart';
import 'package:Highlanders/features/grounds/data/grounds_repository.dart';
import 'package:Highlanders/shared/data/header_icons_repository.dart';
import 'package:Highlanders/features/chat/data/chat_background_repository.dart';
import 'package:Highlanders/features/explore/data/explore_repository.dart';
import 'package:Highlanders/features/swoofi/screens/swoofi_screen.dart';
import 'package:Highlanders/features/feed/services/feed_startup.dart';
import 'package:Highlanders/features/chat/data/chat_media_cache.dart';
import 'package:Highlanders/core/media/media_auto_download.dart';
import 'package:Highlanders/shared/widgets/android_navigation_background.dart';

export 'package:Highlanders/features/posts/services/post_link_router.dart'
    show postIdFromLink;

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
  await AppSettingsRepository.instance.restore();
  FeedStartup.warmBanners();
  unawaited(FeedStartup.ready());
  final selectedSplash = await loadBundledSplash();
  final startupReady = Completer<void>();
  try {
    await const MethodChannel('highlanders/splash')
        .invokeMethod<void>('prepare', selectedSplash)
        .timeout(const Duration(milliseconds: 500));
  } catch (_) {
    // iOS renders the bundled HTML in Flutter.
  }
  runApp(
    HighlandersApp(
      sessionReady: startupReady.future,
      initialSplash: selectedSplash,
    ),
  );
  final sessionReady = Session.restore();
  startupReady.complete(sessionReady.then<void>((_) {}));
  FeedStartup.warm(sessionReady);
  unawaited(
    sessionReady
        .then((signedIn) async {
          if (signedIn) {
            await Future.wait([
              ChatMediaCache.instance.restoreRecent(),
              MediaAutoDownload.instance.restore(),
            ]);
          }
        })
        .catchError((Object _) {}),
  );
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
  unawaited(
    Future.wait<void>([
      sessionReady,
      headerIconsReady.timeout(const Duration(seconds: 3), onTimeout: () {}),
      clubReady.timeout(const Duration(seconds: 4), onTimeout: () {}),
    ]).then<void>((_) {}).catchError((Object _) {}),
  );
  await GroundsRepository.instance.restore();
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
      home ??
      (Session.isSignedIn
          ? const AppShell()
          : const StoreUpdateGate(child: LoginScreen()));

  @override
  Widget build(BuildContext context) {
    final isRunningInTest = WidgetsBinding.instance.runtimeType
        .toString()
        .toLowerCase()
        .contains('test');
    final displaySplash = showSplash ?? !isRunningInTest;

    return MaterialApp(
      title: 'NEUFC',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: clubTheme(),
      builder: (context, child) =>
          AndroidNavigationBackground(child: child ?? const SizedBox.shrink()),
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
