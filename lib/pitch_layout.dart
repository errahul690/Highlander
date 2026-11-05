import 'models.dart';

String? lineupRole(String position) {
  final p = position.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (p.isEmpty) return null;
  if (p == 'g' || p == 'gk' || p == 'keeper' || p.contains('goal')) return 'GK';
  if (p.contains('wingback') || p == 'lwb' || p == 'rwb') return 'DEF';
  if (p.contains('striker') ||
      p.contains('forward') ||
      p.contains('winger') ||
      p.endsWith('wing') ||
      ['f', 'fw', 'st', 'cf', 'lw', 'rw', 'lf', 'rf', 'ss'].contains(p)) {
    return 'FWD';
  }
  if (p.contains('defend') ||
      p.contains('back') ||
      ['d', 'df', 'def', 'cb', 'lb', 'rb', 'lcb', 'rcb', 'sw', 'centrehalf', 'centerhalf'].contains(p)) {
    return 'DEF';
  }
  if (p.contains('mid') ||
      ['m', 'mf', 'mid', 'cm', 'cdm', 'cam', 'am', 'dm', 'dmf', 'amf', 'lm', 'rm'].contains(p)) {
    return 'MID';
  }
  return null;
}

List<int> parseFormation(String formation) {
  final nums = formation
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList();
  if (nums.isEmpty || nums.any((n) => n <= 0 || n > 10)) return [];
  final total = nums.fold<int>(0, (sum, n) => sum + n);
  if (total == 11 && nums.first == 1) return nums.sublist(1);
  if (total == 10) return nums;
  return [];
}

String playerKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String shortShirtName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  final last = parts.last.replaceAll('.', '');
  final initial = parts.first.isEmpty ? '' : parts.first[0].toUpperCase();
  return '$initial. $last';
}

bool isMatchCaptain(MatchLineupPlayer player, String captainName) {
  final key = playerKey(captainName);
  return key.isEmpty ? player.captain : key == playerKey(player.name);
}

double? teamRating(List<MatchLineupPlayer> players) {
  final ratings = players
      .map((player) => player.rating)
      .whereType<double>()
      .toList();
  if (ratings.isEmpty) return null;
  return ratings.reduce((a, b) => a + b) / ratings.length;
}

/// Rows from goalkeeper (index 0) to the most advanced line.
List<List<MatchLineupPlayer>> layoutRows(
  List<MatchLineupPlayer> players, {
  String formation = '',
}) {
  if (players.isEmpty) return [];
  final leftover = [...players];
  MatchLineupPlayer takePreferred(List<String> roles) {
    for (final role in roles) {
      final index = leftover.indexWhere(
        (player) => lineupRole(player.position) == role,
      );
      if (index >= 0) return leftover.removeAt(index);
    }
    return leftover.removeAt(0);
  }

  final gkIndex = leftover.indexWhere(
    (player) => lineupRole(player.position) == 'GK',
  );
  if (gkIndex < 0) return [];
  final gk = leftover.removeAt(gkIndex);
  final outfield = parseFormation(formation);
  final rows = <List<MatchLineupPlayer>>[
    [gk],
  ];
  if (outfield.isNotEmpty) {
    for (var i = 0; i < outfield.length; i++) {
      final count = outfield[i].clamp(0, leftover.length);
      final isLast = i == outfield.length - 1;
      final isFirst = i == 0;
      final roles = isFirst
          ? ['DEF', 'MID', 'FWD']
          : isLast
          ? ['FWD', 'MID', 'DEF']
          : ['MID', 'DEF', 'FWD'];
      rows.add([for (var n = 0; n < count; n++) takePreferred(roles)]);
    }
    if (leftover.isNotEmpty) rows.add([...leftover]);
    return rows;
  }

  List<MatchLineupPlayer> band(String role) =>
      leftover.where((player) => lineupRole(player.position) == role).toList();
  final unknown = leftover
      .where((player) => lineupRole(player.position) == null)
      .toList();
  for (final group in [band('DEF'), band('MID'), band('FWD')]) {
    if (group.isNotEmpty) rows.add(group);
  }
  if (unknown.isNotEmpty) rows.add(unknown);
  return rows;
}
