import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';

/// Native playback sized from the video's metadata, including portrait Reels.
class AppVideoPlayer extends StatefulWidget {
  const AppVideoPlayer({super.key, required this.source, this.autoPlay = true})
    : sharedController = null,
      fullscreenView = false,
      landscape = false;
  const AppVideoPlayer.fullscreen({super.key, required this.source})
    : sharedController = null,
      fullscreenView = true,
      landscape = false,
      autoPlay = true;
  const AppVideoPlayer._fullscreen({
    required this.source,
    required VideoPlayerController controller,
    required this.landscape,
  }) : sharedController = controller,
       fullscreenView = true,
       autoPlay = false;
  final String source;
  final bool autoPlay;
  final VideoPlayerController? sharedController;
  final bool landscape;
  final bool fullscreenView;

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  Timer? _hideTimer;
  bool _failed = false;
  bool _controlsVisible = true;
  double? _dragPosition;
  double _previousVolume = 1;
  bool _fullscreenOpen = false;
  late bool _landscape;
  bool get _isFullscreen => widget.fullscreenView;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _landscape = widget.landscape;
    _controller = widget.sharedController ?? _newController();
    if (_isFullscreen) {
      unawaited(_applyOrientation());
      _armHide();
    }
    if (widget.sharedController == null) {
      unawaited(_initialize(_controller));
    }
  }

  VideoPlayerController _newController() => VideoPlayerController.networkUrl(
    Uri.parse(OtpApi.apiBase).resolve(widget.source),
  );

  Future<void> _initialize(VideoPlayerController controller) async {
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || controller != _controller) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (widget.autoPlay &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        await controller.play();
        if (mounted && controller == _controller) _armHide();
      }
    } catch (_) {
      if (mounted && controller == _controller) setState(() => _failed = true);
    }
  }

  void _reload() {
    if (widget.sharedController != null) return;
    _hideTimer?.cancel();
    final previous = _controller;
    setState(() {
      _controller = _newController();
      _failed = false;
      _controlsVisible = true;
      _dragPosition = null;
      _previousVolume = 1;
    });
    unawaited(previous.dispose().catchError((Object _) {}));
    unawaited(_initialize(_controller));
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _reload();
  }

  Future<void> _applyOrientation() async {
    await SystemChrome.setPreferredOrientations(
      _landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    if (!mounted) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _fullscreen({bool landscape = false}) async {
    if (_isFullscreen) {
      Navigator.of(context).pop();
      return;
    }
    if (_fullscreenOpen) return;
    _hideTimer?.cancel();
    setState(() => _fullscreenOpen = true);
    try {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            key: const ValueKey('video-fullscreen-page'),
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Positioned.fill(
                  child: SafeArea(
                    child: Center(
                      child: AppVideoPlayer._fullscreen(
                        source: widget.source,
                        controller: _controller,
                        landscape: landscape,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    child: IconButton(
                      key: const ValueKey('video-fullscreen-back'),
                      tooltip: 'Exit fullscreen',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      await SystemChrome.setPreferredOrientations(const []);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (mounted) {
        setState(() {
          _fullscreenOpen = false;
          _controlsVisible = true;
        });
        _armHide();
      }
    }
  }

  Future<void> _rotate() async {
    if (!_isFullscreen) return _fullscreen(landscape: true);
    setState(() {
      _landscape = !_landscape;
      _controlsVisible = true;
    });
    await _applyOrientation();
    _armHide();
  }

  void _armHide() {
    _hideTimer?.cancel();
    if (!_controller.value.isPlaying || _dragPosition != null) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying && _dragPosition == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _action(Future<void> Function() action) async {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    try {
      await action();
      if (mounted) _armHide();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _togglePlayback() => _action(() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        await _controller.seekTo(Duration.zero);
      }
      await _controller.play();
    }
  });

  Future<void> _skip(int seconds) => _action(() {
    final value = _controller.value;
    final target = (value.position.inMilliseconds + seconds * 1000).clamp(
      0,
      value.duration.inMilliseconds,
    );
    return _controller.seekTo(Duration(milliseconds: target));
  });

  Future<void> _mute() => _action(() {
    final volume = _controller.value.volume;
    if (volume > 0) {
      _previousVolume = volume;
      return _controller.setVolume(0);
    }
    return _controller.setVolume(_previousVolume);
  });

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _armHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
      unawaited(_controller.pause().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.sharedController == null) {
      unawaited(_controller.dispose().catchError((Object _) {}));
    }
    if (_isFullscreen && widget.sharedController == null) {
      unawaited(SystemChrome.setPreferredOrientations(const []));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  String _time(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final tail = (seconds % 60).toString().padLeft(2, '0');
    return minutes >= 60
        ? '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$tail'
        : '$minutes:$tail';
  }

  Widget _controls(VideoPlayerValue value) {
    final duration = value.duration.inMilliseconds.toDouble();
    final position = (_dragPosition ?? value.position.inMilliseconds.toDouble())
        .clamp(0.0, duration);
    final ended =
        value.duration > Duration.zero && value.position >= value.duration;
    return Stack(
      children: [
        Positioned.fill(
          bottom: 78,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('video-back-10'),
                    tooltip: 'Back 10 seconds',
                    onPressed: () => _skip(-10),
                    icon: const Icon(Icons.replay_10_rounded, size: 34),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black54,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    key: const ValueKey('video-play-pause'),
                    tooltip: value.isPlaying
                        ? 'Pause'
                        : ended
                        ? 'Replay'
                        : 'Play',
                    onPressed: _togglePlayback,
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : ended
                          ? Icons.replay_rounded
                          : Icons.play_arrow_rounded,
                      size: 40,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black54,
                      minimumSize: const Size(60, 60),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    key: const ValueKey('video-forward-10'),
                    tooltip: 'Forward 10 seconds',
                    onPressed: () => _skip(10),
                    icon: const Icon(Icons.forward_10_rounded, size: 34),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black54,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 30,
                    child: Slider(
                      key: const ValueKey('video-seek'),
                      semanticFormatterCallback: (milliseconds) =>
                          _time(milliseconds.round()),
                      min: 0,
                      max: duration > 0 ? duration : 1,
                      value: position,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white38,
                      onChangeStart: duration <= 0
                          ? null
                          : (value) {
                              _hideTimer?.cancel();
                              setState(() => _dragPosition = value);
                            },
                      onChanged: duration <= 0
                          ? null
                          : (value) => setState(() => _dragPosition = value),
                      onChangeEnd: duration <= 0
                          ? null
                          : (value) async {
                              await _action(
                                () => _controller.seekTo(
                                  Duration(milliseconds: value.round()),
                                ),
                              );
                              if (mounted) {
                                setState(() => _dragPosition = null);
                                _armHide();
                              }
                            },
                    ),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_time(position.round())} / ${_time(duration.round())}',
                          key: const ValueKey('video-time'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('video-mute'),
                        tooltip: value.volume == 0 ? 'Unmute' : 'Mute',
                        onPressed: _mute,
                        icon: Icon(
                          value.volume == 0
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                        color: Colors.white,
                      ),
                      IconButton(
                        key: const ValueKey('video-landscape'),
                        tooltip: _isFullscreen && _landscape
                            ? 'Portrait mode'
                            : 'Landscape mode',
                        onPressed: _rotate,
                        icon: const Icon(Icons.screen_rotation_rounded),
                        color: Colors.white,
                      ),
                      IconButton(
                        key: const ValueKey('video-fullscreen'),
                        tooltip: _isFullscreen
                            ? 'Exit fullscreen'
                            : 'Fullscreen',
                        onPressed: _fullscreen,
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                        ),
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          final ratio =
              value.isInitialized &&
                  value.aspectRatio.isFinite &&
                  value.aspectRatio > 0
              ? value.aspectRatio
              : 16 / 9;
          final failed = _failed || value.hasError;
          final visible =
              _controlsVisible || !value.isPlaying || _dragPosition != null;
          if (_fullscreenOpen) {
            return AspectRatio(
              aspectRatio: _isFullscreen
                  ? MediaQuery.sizeOf(context).aspectRatio
                  : ratio,
              child: const ColoredBox(color: Colors.black),
            );
          }
          return Align(
            widthFactor: 1,
            heightFactor: 1,
            child: AspectRatio(
              key: const ValueKey('app-video-aspect'),
              aspectRatio: _isFullscreen
                  ? MediaQuery.sizeOf(context).aspectRatio
                  : ratio,
              child: Material(
                color: Colors.black,
                child: failed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Video could not be loaded.',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: _isFullscreen
                                  ? () => Navigator.of(context).pop()
                                  : _reload,
                              child: Text(_isFullscreen ? 'Back' : 'Retry'),
                            ),
                          ],
                        ),
                      )
                    : !value.isInitialized
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio: ratio,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                          GestureDetector(
                            key: const ValueKey('video-surface'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleControls,
                          ),
                          if (value.isBuffering)
                            const IgnorePointer(
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ExcludeSemantics(
                            excluding: !visible,
                            child: IgnorePointer(
                              ignoring: !visible,
                              child: AnimatedOpacity(
                                opacity: visible ? 1 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: _controls(value),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      );
}
