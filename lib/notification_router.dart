import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_navigation.dart';
import 'club_repository.dart';
import 'feed_match_schedule.dart';
import 'models.dart';
import 'screens/chat_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/live_match_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/match_preview_screen.dart';
import 'screens/post_detail_screen.dart';

class NotificationRouter {
  static void Function(String payload)? _open;
  static String? pending;

  static void attach(void Function(String payload) open) {
    _open = open;
    final waiting = pending;
    pending = null;
    if (waiting != null) open(waiting);
  }

  static void detach(void Function(String payload) open) {
    if (identical(_open, open)) _open = null;
  }

  static void handle(String? raw) {
    if (raw == null || raw.isEmpty) return;
    final open = _open;
    if (open == null) {
      pending = raw;
      return;
    }
    open(raw);
  }

  static Future<void> follow(BuildContext context, String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      await followMap(context, Map<String, dynamic>.from(decoded));
    } catch (_) {}
  }

  static Future<void> followMap(BuildContext context, Map<String, dynamic> data) async {
    if (!context.mounted) return;
    final kind = '${data['kind'] ?? data['type'] ?? ''}';
    if (kind == 'chat' || kind == 'direct_message') {
      final email = '${data['email'] ?? data['senderEmail'] ?? ''}'.trim();
      if (email.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            title: '${data['name'] ?? data['senderName'] ?? 'Chat'}',
            recipientEmail: email,
            isCare: data['isCare'] == true,
          ),
        ),
      );
      return;
    }
    if (kind == 'room' || kind == 'group_invite') {
      final roomId = '${data['roomId'] ?? data['groupId'] ?? ''}'.trim();
      if (roomId.isEmpty) return;
      final name = '${data['name'] ?? data['roomName'] ?? 'Group'}';
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            title: name,
            kind: '${data['roomKind'] ?? 'groups'}',
            room: {'_id': roomId, 'name': name, 'membership': 'active'},
          ),
        ),
      );
      return;
    }
    if (kind == 'post' || '${data['postId'] ?? ''}'.isNotEmpty) {
      final postId = '${data['postId'] ?? ''}'.trim();
      if (postId.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
      );
      return;
    }
    if (kind == 'friends' || kind == 'follow_request') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const FriendsScreen(title: 'Friends', initialTab: 1),
        ),
      );
      return;
    }
    final matchId = '${data['matchId'] ?? ''}'.trim();
    if (kind == 'match' || kind == 'match_stage' || kind == 'match_update' || matchId.isNotEmpty) {
      if (matchId.isNotEmpty) {
        await openMatch(context, matchId);
        return;
      }
    }
    if (!context.mounted) return;
    await openAppDestination(context, '${data['link'] ?? ''}');
  }

  static Future<void> openMatch(BuildContext context, String matchId) async {
    late ClubContent content;
    try {
      content = await ClubRepository.instance.load(forceRefresh: true);
    } catch (_) {
      content = ClubRepository.instance.cachedContent;
    }
    if (!context.mounted) return;
    final fixture = content.fixtures
        .where((item) => item.id == matchId)
        .firstOrNull;
    if (fixture == null) {
      await openAppDestination(context, '/matches');
      return;
    }
    final page = switch (fixturePhase(fixture, DateTime.now())) {
      FeedMatchPhase.preview => MatchPreviewScreen(fixture: fixture),
      FeedMatchPhase.live => LiveMatchScreen(fixture: fixture),
      FeedMatchPhase.upcoming ||
      FeedMatchPhase.report => MatchDetailScreen(fixture: fixture),
    };
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
