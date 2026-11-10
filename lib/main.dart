import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/services.dart';

import 'otp_api.dart';
import 'push_alerts.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'session.dart';
import 'club_repository.dart';
import 'match_card_cache.dart';
import 'realtime_client.dart';
import 'theme.dart';
import 'screens/post_detail_screen.dart';

import 'screens/splash_screen.dart';
import 'splash_cache.dart';
import 'grounds_repository.dart';
import 'header_icons_repository.dart';
import 'chat_background_repository.dart';
import 'explore_repository.dart';
import 'screens/swoofi_screen.dart';
import 'feed_startup.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
const _links = MethodChannel('highlanders/app_links');

String? postIdFromLink(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null) return null;
  String? id;
  if (uri.scheme == 'highlanders' &&
      uri.host == 'post' &&
      uri.pathSegments.length == 1)
    id = uri.pathSegments.first;
  if (['http', 'https'].contains(uri.scheme) &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'post')
    id = uri.pathSegments.last;
  return id != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id) ? id : null;
}

void _openPostLink(String link) {
  final id = postIdFromLink(link);
  if (id != null)
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id)),
    );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PushAlerts.listenForBackgroundMessages();
  await OtpApi.loadEnvironment();
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
  // The Android splash stays up while this local file is read, so Flutter's
  // first frame is already the saved splash.
  final cachedSplash = await SplashCache.instance.read();
  await GroundsRepository.instance.restore();
  runApp(
    HighlandersApp(sessionReady: startupReady, initialSplash: cachedSplash),
  );
  unawaited(GroundsRepository.instance.preload());
  _links.setMethodCallHandler((call) async {
    if (call.method == 'incomingLink' && call.arguments is String)
      _openPostLink(call.arguments as String);
  });
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final initial = await _links.invokeMethod<String>('getInitialLink');
    if (initial != null) _openPostLink(initial);
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
