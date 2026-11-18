/// The app always uses the shipped artwork, independent of admin settings.
Future<Map<String, dynamic>> loadBundledSplash() async => {
  'enabled': true,
  'type': 'stadium',
  'url': 'assets/splash/splash_original.mp4',
  'bg_color': '#160B09',
  // Playback completion, rather than time since Flutter launch, owns handoff.
  'wait_for_completion': true,
  'allow_skip': false,
};
