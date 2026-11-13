import 'package:flutter/services.dart';

/// The app always uses the shipped artwork, independent of admin settings.
Future<Map<String, dynamic>> loadBundledSplash() async => {
  'enabled': true,
  'type': 'html',
  'html_content': await rootBundle.loadString('assets/splash/default.html'),
  'bg_color': '#0E1014',
  'duration': 4,
  'allow_skip': false,
};
