import '../models.dart';

String? youtubeVideoId(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty)
    return null;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www\.|m\.)'), '');
  String? id;
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty)
    id = uri.pathSegments.first;
  if (['youtube.com', 'youtube-nocookie.com'].contains(host)) {
    if (uri.path == '/watch') id = uri.queryParameters['v'];
    if (uri.pathSegments.length >= 2 &&
        ['embed', 'shorts', 'live'].contains(uri.pathSegments.first))
      id = uri.pathSegments[1];
  }
  return id != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id) ? id : null;
}

bool isPlayableHighlight(String value) {
  if (youtubeVideoId(value) != null) return true;
  if (RegExp(
    r'^/uploads/[a-zA-Z0-9_-]+\.(mp4|webm)$',
    caseSensitive: false,
  ).hasMatch(value))
    return true;
  final uri = Uri.tryParse(value);
  return uri != null &&
      ['https', 'http'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      RegExp(r'\.(mp4|webm|m3u8)$', caseSensitive: false).hasMatch(uri.path);
}

String matchHighlightsSource(Fixture fixture) {
  final ordered = [
    ...fixture.videos.where((v) => v.isHighlight),
    ...fixture.videos.where((v) => !v.isHighlight),
  ];
  for (final video in ordered) {
    if (isPlayableHighlight(video.url)) return video.url;
  }
  return isPlayableHighlight(fixture.videoUrl) ? fixture.videoUrl : '';
}

Uri youtubeEmbedUri(String id) =>
    Uri.https('www.youtube-nocookie.com', '/embed/$id', {
      'autoplay': '1',
      'playsinline': '1',
      'rel': '0',
      'modestbranding': '1',
    });

/// YouTube's embed must stay in the card. Watch pages and app links do not.
bool youtubeStaysInApp(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme == 'about' || uri.scheme == 'blob' || uri.scheme == 'data') {
    return true;
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') return false;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www\.|m\.)'), '');
  const allowed = [
    'youtube.com',
    'youtube-nocookie.com',
    'googlevideo.com',
    'ytimg.com',
    'ggpht.com',
    'google.com',
    'gstatic.com',
    'googleusercontent.com',
    'doubleclick.net',
  ];
  final known = allowed.any((name) => host == name || host.endsWith('.$name'));
  if (!known || host == 'youtu.be') return false;
  if (uri.path == '/watch' || uri.path.startsWith('/redirect')) return false;
  return true;
}
const youtubeAppReferrer = 'https://com.highlanders.highlanders/';
