import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Highlanders/features/settings/widgets/store_update_gate.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:Highlanders/features/chat/data/chat_updates.dart';
import 'package:Highlanders/core/notifications/message_alerts.dart';
import 'package:Highlanders/core/notifications/notification_router.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/features/posts/services/post_link_router.dart';
import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/features/explore/data/explore_repository.dart';
import 'package:Highlanders/features/grounds/data/grounds_repository.dart';
import 'package:Highlanders/features/swoofi/screens/swoofi_screen.dart';

import 'package:Highlanders/shared/widgets/app_bottom_navigation.dart';
import 'package:Highlanders/features/feed/widgets/feed_background.dart';
import 'package:Highlanders/features/feed/widgets/feed_welcome.dart';
import 'package:Highlanders/features/grounds/widgets/grounds_host.dart';
import 'package:Highlanders/features/community/screens/community_screen.dart';
import 'package:Highlanders/features/posts/screens/create_post_screen.dart';
import 'package:Highlanders/features/explore/screens/explore_screen.dart';
import 'package:Highlanders/features/feed/screens/feed_screen.dart';
import 'package:Highlanders/features/community/screens/friends_screen.dart';
import 'package:Highlanders/features/profile/screens/profile_screen.dart';
import 'package:Highlanders/features/posts/screens/post_detail_screen.dart';

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
  io.Socket? _settingsSocket;
  Timer? _sessionTimer;

  bool _checkSession() {
    _sessionTimer?.cancel();
    final currentToken = Session.token;
    if (!Session.isSignedIn) {
      unawaited(Session.invalidate(currentToken, allowEmpty: true));
      return false;
    }
    final expiry = Session.tokenExpiresAt;
    if (expiry != null) {
      _sessionTimer = Timer(expiry.difference(DateTime.now()), () {
        unawaited(Session.invalidate(currentToken));
      });
    }
    return true;
  }

  void _selectTab(int index) => setState(() => _index = index);

  late final void Function(String payload) _openNotification = (payload) {
    if (!mounted) return;
    unawaited(NotificationRouter.follow(context, payload));
  };

  late final void Function(String postId) _openSharedPost = (postId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_checkSession()) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
      );
      unawaited(
        const MethodChannel('highlanders/app_links')
            .invokeMethod<void>('consumePostLink', {'postId': postId})
            .catchError((Object _) {}),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  };

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    AppShell._active = this;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_checkSession()) return;
      PostLinkRouter.attach(_openSharedPost);
      NotificationRouter.attach(_openNotification);
    });
    WidgetsBinding.instance.addObserver(this);
    ChatUpdates.instance.acquire();
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
      if (!_checkSession()) return;
      MessageAlerts.setForeground(true);
      _settingsSocket?.connect();
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
    _sessionTimer?.cancel();
    PostLinkRouter.detach(_openSharedPost);
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
    return StoreUpdateGate(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.black,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
        child: GroundsHost(
          child: FeedBackground(
            child: ScrollNotificationObserver(
              child: FeedWelcome(
                enabled: _index == 2,
                builder: (greetingSlot) => Scaffold(
                  extendBody: true,
                  backgroundColor: Colors.transparent,
                  body: IndexedStack(
                    index: _index,
                    children: [
                      FriendsScreen(
                        title: 'Friends',
                        showBack: true,
                        isActive: _index == 0,
                      ),
                      CommunityScreen(title: 'Huddles', isActive: _index == 1),
                      TickerMode(
                        enabled: _index == 2,
                        child: FeedScreen(welcomeGreetingSlot: greetingSlot),
                      ),
                      const ExploreScreen(),
                      ProfileScreen(
                        isActive: _index == 4,
                        onBack: () => setState(() => _index = 2),
                      ),
                    ],
                  ),
                  bottomNavigationBar: AppBottomNavigation(
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
            ),
          ),
        ),
      ),
    );
  }
}
