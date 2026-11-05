bool isNorthEastClub(String name) {
  final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized.contains('northeastunited') ||
      normalized == 'neufc' ||
      normalized.contains('highlander');
}
