/// Admin links take precedence; legacy API responses keep both badges usable.
abstract final class SwoofiStoreLinks {
  static const playStore =
      'https://play.google.com/store/apps/details?id=com.swoofi.swoofi';
  static const appStore = 'https://apps.apple.com/in/app/swoofi/id6740190251';

  static String resolve(Object? value, String fallback) {
    final uri = Uri.tryParse(value is String ? value.trim() : '');
    return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri.toString()
        : fallback;
  }
}
