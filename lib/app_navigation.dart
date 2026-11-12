import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/grounds_host.dart';

import 'screens/alerts_screen.dart';
import 'screens/community_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/grounds_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/polls_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/squad_screen.dart';
import 'screens/swoofi_screen.dart';

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
