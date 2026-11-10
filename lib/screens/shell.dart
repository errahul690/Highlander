import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../chat_updates.dart';
import '../message_alerts.dart';
import '../notification_router.dart';
import '../otp_api.dart';
import '../club_repository.dart';
import '../explore_repository.dart';
import '../splash_cache.dart';
import '../grounds_repository.dart';
import 'swoofi_screen.dart';

import '../widgets/app_bottom_navigation.dart';
import '../widgets/grounds_host.dart';
import 'community_screen.dart';
import 'create_post_screen.dart';
import 'explore_screen.dart';
import 'feed_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 2});
  final int initialIndex;
  static _AppShellState? _active;

  static void openTab(BuildContext context, int index) {
    final state = _active;
    if (state != null && state.mounted) {
      state._selectTab(index);
      final route = ModalRoute.of(state.context);
      Navigator.of(state.context).popUntil(
        (candidate) => candidate == route && !candidate.willHandlePopInternally,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AppShell(initialIndex: index)),
        (_) => false,
      );
    }
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late int _index;
  bool _feedOpening = true;
  io.Socket? _settingsSocket;

  void _selectTab(int index) => setState(() => _index = index);

  late final void Function(String payload) _openNotification = (payload) {
    if (!mounted) return;
    unawaited(NotificationRouter.follow(context, payload));
  };

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    AppShell._active = this;
    WidgetsBinding.instance.addObserver(this);
    ChatUpdates.instance.acquire();
    NotificationRouter.attach(_openNotification);
    unawaited(MessageAlerts.start());
    _settingsSocket = io.io(
      '${OtpApi.apiBase}/public',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _settingsSocket!.on('app-settings:updated', (dynamic event) {
      if (event is Map && event['resource'] == 'splash') {
        unawaited(SplashCache.instance.refresh(force: true));
      }
      if (event is Map && event['resource'] == 'match-card') {
        unawaited(ClubRepository.instance.refreshCardOverlay());
      }
      if (event is Map && event['resource'] == 'grounds') {
        unawaited(GroundsRepository.instance.preload(force: true));
      }
      if (event is Map &&
          (event['resource'] == 'explore' || event['resource'] == 'all')) {
        unawaited(ExploreRepository.instance.load());
      }
      if (event is Map &&
          (event['resource'] == 'swoofi' || event['resource'] == 'all')) {
        unawaited(SwoofiRepository.instance.load(force: true));
      }
    });
    _settingsSocket!.connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      MessageAlerts.setForeground(true);
      _settingsSocket?.connect();
      unawaited(SplashCache.instance.refresh());
      unawaited(GroundsRepository.instance.preload());
      unawaited(ExploreRepository.instance.load());
      unawaited(SwoofiRepository.instance.load(force: true));
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      MessageAlerts.setForeground(false);
      _settingsSocket?.disconnect();
    }
  }

  @override
  void dispose() {
    NotificationRouter.detach(_openNotification);
    if (identical(AppShell._active, this)) AppShell._active = null;
    WidgetsBinding.instance.removeObserver(this);
    ChatUpdates.instance.release();
    _settingsSocket?.dispose();
    super.dispose();
  }

  void _centerTap() {
    if (_index == 2) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
    } else {
      setState(() => _index = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFFF8F8F8),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: GroundsHost(
        child: Scaffold(
          extendBody: true,
          backgroundColor: const Color(0xFFF8F8F8),
          body: IndexedStack(
            index: _index,
            children: [
              FriendsScreen(
                title: 'Friends',
                showBack: false,
                isActive: _index == 0,
              ),
              CommunityScreen(title: 'Huddles', isActive: _index == 1),
              TickerMode(
                enabled: _index == 2,
                child: FeedScreen(
                  onOpeningChanged: (opening) {
                    if (mounted && _feedOpening != opening) {
                      setState(() => _feedOpening = opening);
                    }
                  },
                ),
              ),
              const ExploreScreen(),
              ProfileScreen(
                isActive: _index == 4,
                onBack: () => setState(() => _index = 2),
              ),
            ],
          ),
          bottomNavigationBar: _index == 2 && _feedOpening
              ? null
              : AppBottomNavigation(
                  selectedIndex: _index,
                  onSelect: (index) {
                    if (index == 2) {
                      _centerTap();
                    } else {
                      setState(() => _index = index);
                    }
                  },
                ),
        ),
      ),
    );
  }
}
