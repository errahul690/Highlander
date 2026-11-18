import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'stadium_splash_config.dart';

/// The coordinator's injectable player boundary. Readiness comes from the
/// renderer extension for this exact controller/player ID.
abstract class SplashVideo extends ChangeNotifier {
  bool get initialized;
  bool get completed;
  Object? get error;
  Duration get position;
  Future<void> prepare({required bool enableSound});
  Future<bool> isFirstFrameReady();
  Future<void> play();
  Future<void> pause();
  Widget buildSurface();

  Future<void> release() async => dispose();
}

class AssetSplashVideo extends SplashVideo {
  AssetSplashVideo()
    : controller = VideoPlayerController.asset(
        StadiumSplashConfig.videoAsset,
        // The coordinator exclusively owns pause/resume. Disabling the plugin's
        // automatic observer prevents a competing resume from replaying video.
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: true,
        ),
      ) {
    controller.addListener(_changed);
  }

  static const _frames = MethodChannel('highlanders/video_frame');
  final VideoPlayerController controller;
  bool _disposed = false;
  Future<void>? _disposal;

  @override
  bool get initialized => controller.value.isInitialized;
  @override
  bool get completed => controller.nativePlaybackCompleted;
  @override
  Object? get error => controller.value.errorDescription;
  @override
  Duration get position => controller.value.position;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> prepare({required bool enableSound}) async {
    await controller.initialize();
    if (_disposed) return;
    final size = controller.value.size;
    if ((size.aspectRatio - StadiumSplashConfig.sourceSize.aspectRatio).abs() >
        0.001) {
      throw StateError('Unexpected stadium video dimensions $size');
    }
    await controller.setVolume(enableSound ? 1 : 0);
    if (_disposed) return;
    await controller.setLooping(false);
    // New controllers remain paused at time zero. Never play under the stills.
  }

  @override
  Future<bool> isFirstFrameReady() async =>
      !_disposed &&
      await _frames.invokeMethod<bool>('isFirstFrameReady', {
            'playerId': controller.nativePlayerIdentifier,
          }) ==
          true;

  @override
  Future<void> play() => controller.play();
  @override
  Future<void> pause() => controller.pause();
  @override
  Widget buildSurface() => VideoPlayer(controller);

  @override
  Future<void> release() {
    dispose();
    return _disposal!;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.removeListener(_changed);
    // The plugin owns cancellation of creation and native player teardown.
    _disposal = controller.dispose().catchError((Object error) {
      debugPrint('[stadium-splash] video_disposal_failed $error');
    });
    super.dispose();
  }
}
