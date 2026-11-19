Uri? instagramVideoPermalink(String source) {
  final uri = Uri.tryParse(source.trim());
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      ![
        'instagram.com',
        'www.instagram.com',
        'm.instagram.com',
      ].contains(uri.host.toLowerCase())) {
    return null;
  }
  final match = RegExp(
    r'^/(?:(?!share/|stories/)[A-Za-z0-9_.]+/)?(reels?|p|tv)/([A-Za-z0-9_-]+)/?(?:embed/(?:captioned/)?)?$',
  ).firstMatch(uri.path);
  if (match == null) return null;
  final type = match[1] == 'reels' ? 'reel' : match[1];
  return Uri.https('www.instagram.com', '/$type/${match[2]}/');
}
