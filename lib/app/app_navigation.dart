import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:Highlanders/features/grounds/widgets/grounds_host.dart';

import 'package:Highlanders/features/notifications/screens/alerts_screen.dart';
import 'package:Highlanders/features/community/screens/community_screen.dart';
import 'package:Highlanders/features/explore/screens/explore_screen.dart';
import 'package:Highlanders/features/community/screens/friends_screen.dart';
import 'package:Highlanders/features/gallery/screens/gallery_screen.dart';
import 'package:Highlanders/features/grounds/screens/grounds_screen.dart';
import 'package:Highlanders/features/matches/screens/matches_screen.dart';
import 'package:Highlanders/features/profile/screens/profile_screen.dart';
import 'package:Highlanders/features/polls/screens/polls_screen.dart';
import 'package:Highlanders/features/settings/screens/settings_screen.dart';
import 'package:Highlanders/features/squad/screens/squad_screen.dart';
import 'package:Highlanders/features/swoofi/screens/swoofi_screen.dart';

Future<void> openAppDestination(BuildContext context, String link) async {
  if (link == '/grounds' && GroundsHost.open(context)) return;
  final pages = <String, Widget>{
    '/squad': const SquadScreen(),
    '/matches': const MatchesScreen(),
    '/gallery': const GalleryScreen(),
    '/grounds': const GroundsScreen(),
    '/alerts': const AlertsScreen(),
    '/profile': const ProfileScreen(),
    '/polls': const PollsScreen(),
    '/settings': const SettingsScreen(),
    '/friends': const FriendsScreen(title: 'Friends'),
    '/circles': const CommunityScreen(),
    '/explore': const ExploreScreen(),
    '/swoofi': const SwoofiScreen(),
  };
  if (pages[link] != null) {
    Navigator.of(context).push(
      link == '/grounds'
          ? GroundsScreen.route()
          : MaterialPageRoute(builder: (_) => pages[link]!),
    );
    return;
  }
  if (link.isEmpty) return;
  try {
    final uri = Uri.parse(link);
    if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty)
      throw const FormatException();
    await const MethodChannel('highlanders/app_links')
        .invokeMethod<void>('openUrl', {'url': uri.toString()});
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this link. Please try again.'),
        ),
      );
  }
}
