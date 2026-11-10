String sharedPostUrl(String postId) => 'https://highlanders.app/post/$postId';

/// Holds shared posts until the signed-in app shell is ready.
class PostLinkRouter {
  static String? pending;
  static void Function(String postId)? _open;

  static void handle(String link) {
    final id = postIdFromLink(link);
    if (id == null) return;
    final open = _open;
    if (open == null) {
      pending = id;
    } else {
      open(id);
    }
  }

  static void attach(void Function(String postId) open) {
    _open = open;
    final id = pending;
    pending = null;
    if (id != null) open(id);
  }

  static void detach(void Function(String postId) open) {
    if (identical(_open, open)) _open = null;
  }
}

String? postIdFromLink(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null) return null;
  String? id;
  if (uri.scheme.toLowerCase() == 'highlanders' &&
      uri.host.toLowerCase() == 'post' &&
      uri.pathSegments.length == 1) {
    id = uri.pathSegments.first;
  }
  if (['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'post') {
    id = uri.pathSegments.last;
  }
  return id != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id) ? id : null;
}
