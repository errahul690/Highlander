import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../otp_api.dart';
import 'video_poster.dart';

class PostVideo extends StatefulWidget {
  const PostVideo({
    super.key,
    required this.source,
    this.local = false,
    this.onOpen,
    this.autoPlay = false,
    this.aspectRatio = 4 / 3,
  });
  final String source;
  final bool local;
  final VoidCallback? onOpen;
  final bool autoPlay;
  final double aspectRatio;
  @override
  State<PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<PostVideo> with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _started = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.local
        ? VideoPlayerController.file(File(widget.source))
        : VideoPlayerController.networkUrl(
            Uri.parse(OtpApi.apiBase).resolve(widget.source),
          );
    if (widget.autoPlay) _start();
  }

  Future<void> _start() async {
    if (widget.onOpen != null) {
      widget.onOpen!();
      return;
    }
    if (_started) return;
    setState(() => _started = true);
    try {
      await _controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() => _ready = true);
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await _controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggle({bool pause = false}) async {
    if (!_ready) return;
    try {
      if (pause || _controller.value.isPlaying) {
        await _controller.pause();
      } else {
        await _controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _toggle(pause: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose().catchError((Object _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ColoredBox(
          color: Colors.black,
          child: _failed
              ? const Center(
                  child: Text(
                    'Video could not be loaded.',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : !_started
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPoster(source: widget.source, local: widget.local),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const ValueKey('post-video-open'),
                        onTap: _start,
                        child: Center(
                          child: IconButton.filled(
                            tooltip: widget.onOpen != null
                                ? 'Watch reels'
                                : 'Play video',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _start,
                            iconSize: 36,
                            icon: const Icon(Icons.play_arrow_rounded),
                          ),
                        ),
                      ),
                    ),
                    if (widget.onOpen != null)
                      const Positioned(
                        bottom: 10,
                        right: 10,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Watch reels',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : !_ready
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio > 0
                            ? _controller.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                    ValueListenableBuilder(
                      builder: (context, value, child) => IconButton.filled(
                        tooltip: value.isPlaying ? 'Pause video' : 'Play video',
                        onPressed: _toggle,
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                      valueListenable: _controller,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
