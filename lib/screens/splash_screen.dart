import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_banners_repository.dart';
import '../feed_startup.dart';
import '../otp_api.dart';
import '../splash_cache.dart';
import '../session.dart';
import '../widgets/startup_loader.dart';

const _nativeSplash = MethodChannel('highlanders/splash');

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.nextScreen,
    this.resolveNext,
    this.client,
    this.sessionReady,
    this.initialSplash,
  }) : assert(nextScreen != null || resolveNext != null);

  final Widget? nextScreen;
  final Widget Function()? resolveNext;
  final http.Client? client;
  final Future<void>? sessionReady;
  final Map<String, dynamic>? initialSplash;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Map<String, dynamic>? _splash;
  bool _proceeded = false;
  bool _holding = false;
  bool _loaderReady = false;
  Completer<void>? _goalFinished;
  Timer? _timer;
  Timer? _nativeReadyTimeout;
  Completer<Map<String, dynamic>?>? _nativePlayback;
  bool _mediaReady = false;
  bool _nativeChecked = false;
  bool _timerArmed = false;

  WebViewController? _webController;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.client == null) unawaited(FeedStartup.ready());
    _nativeSplash.setMethodCallHandler((call) async {
      if (call.method == 'skip') _proceed();
    });

    final initial = widget.initialSplash;
    if (initial != null && initial['enabled'] != false) {
      _installSplash(initial);
      _armTimer(initial);
    } else if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _proceed());
    } else if (widget.client == null) {
      unawaited(_showBundledSplash());
    }
    unawaited(_refreshForNextLaunch());
  }

  Future<void> _showBundledSplash() async {
    try {
      final html = await rootBundle.loadString('assets/splash/default.html');
      if (!mounted || _proceeded || _splash != null) return;
      final data = <String, dynamic>{
        'enabled': true,
        'type': 'html',
        'html_content': html,
        'bg_color': '#0E1014',
        'duration': 6,
        'allow_skip': false,
      };
      _applySplash(data);
    } catch (_) {}
  }

  Future<void> _refreshForNextLaunch() async {
    final fresh = await SplashCache.instance.refresh(
      client: widget.client,
      force: true,
    );
    if (!mounted || _proceeded || fresh == null) return;
    if (fresh['enabled'] == false) {
      // A setting saved for the next launch must not cut off this playback.
      if (_splash == null && widget.client != null) _proceed();
      return;
    }
    final allowSkip = fresh['allow_skip'] == true;
    if (!mounted || _proceeded) return;
    // A test client has no saved splash. A real launch keeps the splash
    // already on screen and stores the new one for the next open.
    if (widget.client != null && widget.initialSplash == null) {
      _applySplash(fresh, restartTimer: _splash == null);
    } else if (_splash != null && _splash!['allow_skip'] != allowSkip) {
      setState(() => _splash = {..._splash!, 'allow_skip': allowSkip});
    }
    try {
      await _nativeSplash.invokeMethod<void>('setAllowSkip', {
        'allow': allowSkip,
      });
    } catch (_) {}
  }

  void _installSplash(Map<String, dynamic> data) {
    _splash = data;
    _mediaReady = false;
    _timerArmed = false;
    final type = '${data['type'] ?? 'gif'}'.toLowerCase();
    final url = '${data['url'] ?? ''}'.trim();
    final htmlContent = '${data['html_content'] ?? ''}'.trim();
    final localPath = '${data['_local_media_path'] ?? ''}';
    final localHtmlPath = '${data['_local_html_path'] ?? ''}';

    if (type == 'html' &&
        (htmlContent.isNotEmpty || localHtmlPath.isNotEmpty)) {
      _initHtml(htmlContent, localHtmlPath);
    } else if (type == 'video' && url.isNotEmpty) {
      _initVideo(url, localPath);
    } else if (type == 'lottie' && url.isNotEmpty) {
      _initLottie(url);
    }
  }

  int get _playbackMilliseconds {
    final configured =
        (((_splash?['duration'] as num?)?.toDouble() ?? 3) * 1000).round();
    final video = _videoController?.value.duration.inMilliseconds ?? 0;
    // The bundled mountain reveal reaches the summit at 4.25 s, followed by
    // its 1.4 s finish. Older cached copies can still have a 3 s setting.
    final html = '${_splash?['html_content'] ?? ''}';
    final bundled = html.contains('const ROAD_START = 1.25, ROAD_DUR = 3.0;')
        ? 6000
        : 0;
    var duration = video > configured ? video : configured;
    if (bundled > duration) duration = bundled;
    return duration;
  }

  Future<void> _armTimer(Map<String, dynamic> data) async {
    _nativeChecked = false;
    _timer?.cancel();
    // A broken WebView/image must not strand the app on splash forever.
    _timer = Timer(
      const Duration(seconds: 15),
      () => unawaited(_holdForFeed()),
    );
    Map<String, dynamic>? native;
    if ('${data['type']}'.toLowerCase() == 'html') {
      final playback = Completer<Map<String, dynamic>?>();
      _nativePlayback = playback;
      _nativeReadyTimeout = Timer(const Duration(seconds: 12), () {
        if (!playback.isCompleted) playback.complete(null);
      });
      unawaited(
        _nativeSplash
            .invokeMapMethod<String, dynamic>('waitUntilReady')
            .then(
              (value) {
                if (!playback.isCompleted) playback.complete(value);
              },
              onError: (Object _) {
                if (!playback.isCompleted) playback.complete(null);
              },
            ),
      );
      native = await playback.future;
      _nativeReadyTimeout?.cancel();
    }
    if (!mounted || _proceeded || _holding) return;
    _nativeChecked = true;
    if (native?['active'] == true) {
      _timerArmed = true;
      final elapsed = (native?['elapsedMs'] as num?)?.toInt() ?? 0;
      final minimum = (native?['minimumDurationMs'] as num?)?.toInt() ?? 0;
      final duration = minimum > _playbackMilliseconds
          ? minimum
          : _playbackMilliseconds;
      _startTimer(duration - elapsed);
    } else if (_mediaReady) {
      _onMediaReady();
    }
  }

  void _onMediaReady() {
    if (!mounted || _proceeded || _holding) return;
    _mediaReady = true;
    if (!_nativeChecked || _timerArmed) return;
    _timerArmed = true;
    _startTimer(_playbackMilliseconds);
  }

  void _applySplash(Map<String, dynamic> data, {bool restartTimer = true}) {
    if (data['enabled'] == false) {
      _proceed();
      return;
    }
    _installSplash(data);
    setState(() {});
    if (restartTimer || _timer == null) _armTimer(data);
  }

  void _initHtml(String html, [String localFilePath = '']) {
    try {
      var content = html;
      if (content.isEmpty &&
          localFilePath.isNotEmpty &&
          File(localFilePath).existsSync()) {
        try {
          content = File(localFilePath).readAsStringSync();
        } catch (_) {}
      }

      if (content.isEmpty) return;

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _onMediaReady();
            },
            onWebResourceError: (err) {
              debugPrint('WebView resource error: ${err.description}');
            },
          ),
        )
        ..loadHtmlString(content);

      _webController = controller;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to initialize WebView: $e');
      _onMediaReady();
    }
  }

  void _initLottie(String lottieUrl) {
    final fullUrl = lottieUrl.startsWith('/')
        ? '${OtpApi.apiBase}$lottieUrl'
        : lottieUrl;
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'SplashPlayback',
          onMessageReceived: (_) => _onMediaReady(),
        )
        ..loadHtmlString('''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <script src="https://unpkg.com/@lottiefiles/lottie-player@latest/dist/lottie-player.js"></script>
    <style>
      body { margin:0; padding:0; display:flex; justify-content:center; align-items:center; height:100vh; background:transparent; overflow:hidden; }
      lottie-player { width: 100%; height: 100%; }
    </style>
  </head>
  <body>
    <lottie-player id="animation" src="$fullUrl" background="transparent" speed="1" loop autoplay></lottie-player>
    <script>
      const player = document.getElementById('animation');
      player.addEventListener('ready', () => SplashPlayback.postMessage('ready'), {once: true});
    </script>
  </body>
</html>
''');
      _webController = controller;
      if (mounted) setState(() {});
    } catch (_) {
      _onMediaReady();
    }
  }

  void _initVideo(String videoUrl, String localPath) {
    final fullUrl = videoUrl.startsWith('/')
        ? '${OtpApi.apiBase}$videoUrl'
        : videoUrl;
    try {
      _videoController?.dispose();
      _videoController =
          localPath.isNotEmpty && File(localPath).existsSync()
                ? VideoPlayerController.file(File(localPath))
                : VideoPlayerController.networkUrl(Uri.parse(fullUrl))
            ..initialize().then((_) {
              if (mounted) {
                _videoController?.play();
                _videoController?.setLooping(false);
                _onMediaReady();
                setState(() {});
              }
            });
    } catch (_) {}
  }

  void _startTimer(int milliseconds) {
    _timer?.cancel();
    if (milliseconds <= 0) {
      unawaited(_holdForFeed());
      return;
    }
    _timer = Timer(Duration(milliseconds: milliseconds), () {
      unawaited(_holdForFeed());
    });
  }

  /// Splash time is for the artwork. If banners and gallery are still downloading,
  /// keep the full-screen loader up instead of opening a half-loaded feed.
  Future<void> _showLoader() async {
    if (!mounted) return;
    if (!_holding) setState(() => _holding = true);
    // Android's cached HTML splash sits above Flutter, including this loader.
    try {
      await _nativeSplash.invokeMethod<void>('hide');
    } catch (_) {}
  }

  Future<void> _holdForFeed() async {
    if (_proceeded || !mounted) return;
    if (widget.client != null) {
      await _proceed();
      return;
    }
    final session = widget.sessionReady;
    if (session != null) {
      try {
        await session;
      } catch (_) {}
    }
    if (!mounted || _proceeded) return;
    // The loader prepares the feed. A signed-out launch goes straight to sign-in.
    if (!Session.isSignedIn) {
      await _proceed();
      return;
    }
    if (!FeedStartup.isReady) {
      await _showLoader();
      try {
        await FeedStartup.ready().timeout(const Duration(seconds: 15));
      } catch (_) {}
    }
    // ready() can time out on gallery work while banner files are still
    // downloading. Keep the loader up until those pictures are saved.
    try {
      await AppBannersRepository.instance.whenImagesReady().timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {}
    FeedStartup.heldForFeed = true;
    if (mounted && !_proceeded) await _proceed();
  }

  Future<void> _proceed() async {
    if (_proceeded || !mounted) return;
    _proceeded = true;
    _timer?.cancel();
    _cancelNativeWait();
    _videoController?.pause();
    final ready = widget.sessionReady;
    if (ready != null) {
      try {
        await ready;
      } catch (_) {}
    }
    if (!mounted) return;
    final openingFeed = Session.isSignedIn && widget.client == null;
    if (openingFeed && !_holding && !FeedStartup.isReady) {
      await _showLoader();
      try {
        await FeedStartup.ready().timeout(const Duration(seconds: 15));
      } catch (_) {}
      try {
        await AppBannersRepository.instance.whenImagesReady().timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {}
      FeedStartup.heldForFeed = true;
    }
    if (!mounted) return;
    if (openingFeed && _holding) {
      if (Session.isSignedIn && widget.client == null) {
        await FeedStartup.waitForPosts();
      }
      if (!mounted) return;
      final goal = Completer<void>();
      _goalFinished = goal;
      setState(() => _loaderReady = true);
      await goal.future;
      if (!mounted) return;
      if (Session.isSignedIn && widget.client == null) {
        FeedStartup.finishEntrance();
      }
    }
    final next = widget.resolveNext?.call() ?? widget.nextScreen!;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 360), () async {
      try {
        await _nativeSplash.invokeMethod<void>('hide');
      } catch (_) {}
    });
  }

  Color _parseBgColor(String? hex) {
    const page = Color(0xFF0E1014);
    if (hex == null || hex.isEmpty) return page;
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    final val = int.tryParse(clean, radix: 16);
    if (val == null) return page;
    final color = Color(val);
    // The old placeholder was a flat maroon screen. The splash artwork is dark.
    if (color.toARGB32() == 0xFF8E1B13) return page;
    return color;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelNativeWait();
    _videoController?.dispose();
    final goal = _goalFinished;
    if (goal != null && !goal.isCompleted) goal.complete();
    super.dispose();
  }

  void _cancelNativeWait() {
    _nativeReadyTimeout?.cancel();
    final playback = _nativePlayback;
    if (playback != null && !playback.isCompleted) playback.complete(null);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _parseBgColor(_splash?['bg_color'] as String?);
    final allowSkip = _splash?['allow_skip'] == true;
    final type = '${_splash?['type'] ?? 'gif'}'.toLowerCase();
    final url = '${_splash?['url'] ?? ''}'.trim();
    final fullUrl = url.startsWith('/') ? '${OtpApi.apiBase}$url' : url;
    final localPath = '${_splash?['_local_media_path'] ?? ''}';

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Splash Media Content (Full-bleed for HTML/Lottie, centered for image/video)
          Positioned.fill(child: _buildMediaContent(type, fullUrl, localPath)),

          if (_holding)
            Positioned.fill(
              child: StartupLoader(
                ready: _loaderReady,
                onFinished: () {
                  final goal = _goalFinished;
                  if (goal != null && !goal.isCompleted) goal.complete();
                },
              ),
            ),

          // Allow Tap Anywhere or Skip Button
          if (allowSkip && !_holding)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              child: SafeArea(
                child: Center(
                  child: GestureDetector(
                    onTap: _proceed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE616181D),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x59000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Text(
                        'SKIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(String type, String fullUrl, String localPath) {
    if (_splash == null) return const SizedBox.expand();

    // 1. Custom HTML or Lottie (via WebView)
    if (type == 'html' || type == 'lottie') {
      if (_webController == null) return const SizedBox.expand();
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: WebViewWidget(controller: _webController!),
      );
    }

    // 2. Video Player
    if (type == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );
      }
      return const SizedBox.expand();
    }

    // 3. Animated GIF or Static Image
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        frameBuilder: _imageFrame,
        errorBuilder: (_, _, _) => _failedImage(),
      );
    }
    if (fullUrl.isNotEmpty) {
      return Image.network(
        fullUrl,
        fit: BoxFit.contain,
        frameBuilder: _imageFrame,
        errorBuilder: (_, _, _) => _failedImage(),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _onMediaReady());
    return const SizedBox.expand();
  }

  Widget _imageFrame(
    BuildContext context,
    Widget child,
    int? frame,
    bool synchronous,
  ) {
    if (frame != null || synchronous) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onMediaReady());
    }
    return child;
  }

  Widget _failedImage() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _onMediaReady());
    return const SizedBox.expand();
  }
}
