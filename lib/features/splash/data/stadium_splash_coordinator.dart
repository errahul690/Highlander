import 'dart:async';

import 'package:flutter/foundation.dart';

import 'splash_video.dart';
import 'stadium_splash_config.dart';

enum StadiumSplashPhase {
  loadingImages,
  lights,
  waitingForVideo,
  revealing,
  playing,
  finished,
}

/// Foreground time is supplied by the widget's ticker. No timers survive
/// disposal or accrue time while the app is inactive.
class StadiumSplashCoordinator extends ChangeNotifier {
  StadiumSplashCoordinator({
    required this.video,
    required this.bootstrap,
    this.retryBootstrap,
    this.config = const StadiumSplashConfig(),
    bool waitForNativeHandoff = false,
  }) : nativeHandoffReady = !waitForNativeHandoff;

  final SplashVideo video;
  final Future<void> bootstrap;
  final Future<void> Function()? retryBootstrap;
  final StadiumSplashConfig config;
  StadiumSplashPhase phase = StadiumSplashPhase.loadingImages;
  int stage = 0;
  Duration stageElapsed = Duration.zero;
  Duration _foreground = Duration.zero;
  Duration _imageWait = Duration.zero;
  Duration _videoWait = Duration.zero;
  Duration _stall = Duration.zero;
  Duration _poll = Duration.zero;
  Duration _lastPosition = Duration.zero;
  bool active = true;
  bool imagesReady = false;
  bool firstStillPainted = false;
  bool nativeHandoffReady;
  bool videoPrepared = false;
  bool firstFrameReady = false;
  bool bootstrapReady = false;
  Object? bootstrapError;
  Object? mediaError;
  bool _querying = false;
  bool _disposed = false;
  bool _videoReleased = false;
  Future<void>? _videoRelease;
  bool _started = false;
  bool _claimed = false;
  bool _retrying = false;
  bool _frameLogged = false;
  Future<void> _commands = Future<void>.value();

  bool get introFinished => phase == StadiumSplashPhase.finished;
  bool get canShowDestination => active && introFinished && bootstrapReady;
  bool get showVideo =>
      phase == StadiumSplashPhase.revealing ||
      phase == StadiumSplashPhase.playing ||
      (introFinished && firstFrameReady);
  double get stillOpacity {
    if (stage == 0 || config.transitionDuration == Duration.zero) return 1;
    return (stageElapsed.inMicroseconds /
            config.transitionDuration.inMicroseconds)
        .clamp(0.0, 1.0);
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    video.addListener(_videoChanged);
    unawaited(_observeBootstrap(bootstrap));
    unawaited(_prepareVideo());
  }

  void _stamp(String event) {
    if (config.diagnostics) {
      debugPrint(
        '[stadium-splash] $event foreground=${_foreground.inMilliseconds}ms',
      );
    }
  }

  Future<void> _observeBootstrap(Future<void> future) async {
    try {
      await future;
      if (_disposed) return;
      bootstrapReady = true;
      bootstrapError = null;
    } catch (error) {
      if (_disposed) return;
      bootstrapError = error;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> retry() async {
    final callback = retryBootstrap;
    if (_disposed || _retrying || callback == null) return;
    _retrying = true;
    bootstrapError = null;
    notifyListeners();
    await _observeBootstrap(Future<void>.sync(callback));
    _retrying = false;
  }

  Future<void> _prepareVideo() async {
    try {
      await video.prepare(enableSound: config.enableSound);
      if (_disposed || introFinished) return;
      videoPrepared = true;
      _stamp('video_initialized');
      notifyListeners();
      unawaited(_queryFrame());
    } catch (error) {
      _mediaFailed(error);
    }
  }

  void markFirstStillPainted() {
    if (_disposed || firstStillPainted) return;
    firstStillPainted = true;
    _stamp('first_flutter_still');
    _beginLights();
  }

  void markImagesReady() {
    if (_disposed) return;
    imagesReady = true;
    _beginLights();
  }

  void markNativeHandoffReady() {
    if (_disposed || nativeHandoffReady) return;
    nativeHandoffReady = true;
    _stamp('native_handoff_completed');
    _beginLights();
  }

  void _beginLights() {
    if (phase != StadiumSplashPhase.loadingImages ||
        !imagesReady ||
        !nativeHandoffReady ||
        !firstStillPainted) {
      return;
    }
    phase = StadiumSplashPhase.lights;
    stageElapsed = Duration.zero;
    notifyListeners();
  }

  void imagesFailed(Object error) {
    if (_disposed || introFinished) return;
    mediaError = error;
    _finish('image_failed');
  }

  void advance(Duration elapsed) {
    if (_disposed ||
        !active ||
        elapsed <= Duration.zero ||
        canShowDestination) {
      return;
    }
    _foreground += elapsed;
    if (phase == StadiumSplashPhase.loadingImages) {
      _imageWait += elapsed;
      if (_imageWait >= config.imageTimeout) {
        imagesFailed(TimeoutException('Stadium images'));
      }
    } else if (phase == StadiumSplashPhase.lights) {
      stageElapsed += elapsed;
      final lastStage = StadiumSplashConfig.images.length - 1;
      final duration = stage == 0
          ? config.firstStillDuration
          : stage == lastStage
          ? config.lastStillDuration
          : config.stageDuration;
      if (stageElapsed >= duration) {
        if (stage < lastStage) {
          // Advance at most one image per frame, preserving every lighting step
          // even after a slow frame. Transition time belongs to the new stage.
          stage++;
          stageElapsed = Duration.zero;
        } else {
          phase = StadiumSplashPhase.waitingForVideo;
          // Recheck the current native surface at handoff. A prior frame can
          // become stale after a resize/surface recreation during the lights.
          firstFrameReady = false;
          unawaited(_queryFrame());
          _stamp('image_sequence_completed');
        }
      }
    } else if (phase == StadiumSplashPhase.waitingForVideo) {
      _videoWait += elapsed;
      if (_videoWait >= config.readinessTimeout) {
        _finish('video_readiness_timeout');
      }
    } else if (phase == StadiumSplashPhase.playing) {
      _stall += elapsed;
      if (_stall >= config.playbackStallTimeout) _finish('playback_stalled');
    }
    if (videoPrepared && !firstFrameReady && !introFinished) {
      _poll += elapsed;
      if (_poll >= config.framePollInterval) {
        _poll = Duration.zero;
        unawaited(_queryFrame());
      }
    }
    _tryReveal();
    if (!_disposed) notifyListeners();
  }

  Future<void> _queryFrame() async {
    if (_disposed || _querying || !active || !videoPrepared || introFinished) {
      return;
    }
    _querying = true;
    try {
      final ready = await video.isFirstFrameReady();
      if (_disposed || !active || introFinished) return;
      firstFrameReady = ready;
      if (ready) {
        if (!_frameLogged) {
          _frameLogged = true;
          _stamp('first_frame_ready');
        }
        _tryReveal();
        notifyListeners();
      }
    } catch (error) {
      _mediaFailed(error);
    } finally {
      _querying = false;
    }
  }

  void _tryReveal() {
    if (!active || phase != StadiumSplashPhase.waitingForVideo) return;
    if (mediaError != null) {
      _finish('video_failed');
    } else if (videoPrepared && firstFrameReady) {
      phase = StadiumSplashPhase.revealing;
    }
  }

  /// Called after the overlay has been removed in a Flutter frame. This is a
  /// visibility gate, independent of the native renderer's readiness signal.
  void visibleVideoPainted() {
    if (_disposed || !active || phase != StadiumSplashPhase.revealing) return;
    phase = StadiumSplashPhase.playing;
    _stamp('video_revealed');
    _stall = Duration.zero;
    _syncPlayback();
    notifyListeners();
  }

  void _videoChanged() {
    if (_disposed) return;
    if (video.error != null) {
      _mediaFailed(video.error!);
    } else if (phase == StadiumSplashPhase.playing) {
      if (video.position != _lastPosition) {
        _lastPosition = video.position;
        _stall = Duration.zero;
      }
      if (video.completed) _finish('video_completed');
    }
  }

  void _mediaFailed(Object error) {
    if (_disposed || introFinished) return;
    mediaError = error;
    if (phase == StadiumSplashPhase.playing ||
        phase == StadiumSplashPhase.revealing) {
      _finish('video_failed');
    } else {
      _tryReveal();
      notifyListeners();
    }
  }

  void _finish(String reason) {
    if (_disposed || introFinished) return;
    phase = StadiumSplashPhase.finished;
    _stamp(reason);
    _syncPlayback();
    notifyListeners();
  }

  void setActive(bool value) {
    if (_disposed || active == value) return;
    active = value;
    if (!introFinished && phase != StadiumSplashPhase.playing) {
      firstFrameReady = false;
      if (phase == StadiumSplashPhase.revealing) {
        phase = StadiumSplashPhase.waitingForVideo;
      }
    }
    _syncPlayback();
    if (value) unawaited(_queryFrame());
    notifyListeners();
  }

  void _syncPlayback() {
    // Serialize commands and re-evaluate intent when each reaches the player.
    // Rapid lifecycle changes cannot leave a queued play running in background.
    _commands = _commands.then((_) async {
      if (_disposed || _videoReleased || !videoPrepared) return;
      try {
        if (active && phase == StadiumSplashPhase.playing) {
          await video.play();
        } else {
          await video.pause();
        }
      } catch (error) {
        _mediaFailed(error);
      }
    });
  }

  bool claimDestination() {
    if (_disposed || _claimed || !canShowDestination) return false;
    _claimed = true;
    _stamp('navigation');
    return true;
  }

  Future<void> releaseVideo() {
    if (_videoReleased) return _videoRelease!;
    _videoReleased = true;
    video.removeListener(_videoChanged);
    return _videoRelease = video.release();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(releaseVideo());
    super.dispose();
  }
}
