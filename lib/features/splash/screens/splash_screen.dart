import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:Highlanders/shared/widgets/startup_loader.dart';
import 'package:Highlanders/core/startup/startup_visibility.dart';

import '../data/splash_video.dart';
import '../data/stadium_splash_config.dart';
import '../data/stadium_splash_coordinator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.nextScreen,
    this.resolveNext,
    this.sessionReady,
    this.retryBootstrap,
    this.releaseNativeLaunch,
    this.video,
    this.config = const StadiumSplashConfig(),
    // Retained for callers using the existing startup widget. The shipped
    // stadium sequence owns media selection, independent of admin settings.
    this.client,
    this.initialSplash,
    this.feedReady,
  }) : assert(nextScreen != null || resolveNext != null);

  final Widget? nextScreen;
  final Widget Function()? resolveNext;
  final Future<void>? sessionReady;
  final Future<void> Function()? retryBootstrap;
  final VoidCallback? releaseNativeLaunch;
  final SplashVideo? video;
  final StadiumSplashConfig config;
  final http.Client? client;
  final Map<String, dynamic>? initialSplash;
  final Future<void>? feedReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final StadiumSplashCoordinator _coordinator;
  late final Ticker _ticker;
  final _destinationVisible = ValueNotifier(false);
  final _providers = [
    for (final path in StadiumSplashConfig.images) AssetImage(path),
  ];
  Duration _lastTick = Duration.zero;
  bool _loading = false;
  bool _firstReady = false;
  bool _handoffScheduled = false;
  bool _destinationScheduled = false;
  bool _showDestination = false;
  bool _welcomeReady = false;
  bool _launchReleased = false;
  bool _nativeHandoffStarted = false;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _coordinator = StadiumSplashCoordinator(
      video: widget.video ?? AssetSplashVideo(),
      bootstrap: widget.sessionReady ?? Future<void>.value(),
      retryBootstrap: widget.retryBootstrap,
      config: widget.config,
      waitForNativeHandoff: true,
    );
    _coordinator.addListener(_changed);
    _ticker = createTicker((elapsed) {
      final delta = elapsed - _lastTick;
      _lastTick = elapsed;
      _coordinator.advance(delta);
    });
    _coordinator.start();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _coordinator.setActive(
      lifecycle == null || lifecycle == AppLifecycleState.resumed,
    );
    if (_coordinator.active) _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) return;
    _loading = true;
    unawaited(_prepareImages());
  }

  Future<bool> _cache(ImageProvider provider) async {
    var succeeded = true;
    await precacheImage(
      provider,
      context,
      onError: (error, stack) {
        succeeded = false;
        _coordinator.imagesFailed(error);
      },
    );
    return succeeded;
  }

  Future<void> _prepareImages() async {
    try {
      final first = await _cache(_providers.first);
      if (!mounted || !first || _coordinator.introFinished) return;
      setState(() => _firstReady = true);
      _releaseLaunch();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _coordinator.markFirstStillPainted();
        unawaited(_releaseNativeCover());
      });
      final results = await Future.wait([
        for (final provider in _providers.skip(1)) _cache(provider),
      ]);
      if (!mounted || results.contains(false) || _coordinator.introFinished) {
        return;
      }
      _coordinator.markImagesReady();
    } catch (error) {
      if (mounted) _coordinator.imagesFailed(error);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_coordinator.introFinished) {
      _releaseLaunch();
      unawaited(_releaseNativeCover());
    }
    if (_coordinator.phase == StadiumSplashPhase.revealing &&
        !_handoffScheduled) {
      _handoffScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handoffScheduled = false;
        if (mounted) _coordinator.visibleVideoPainted();
      });
    }
    if (_coordinator.canShowDestination && !_destinationScheduled) {
      _destinationScheduled = true;
      // Mount the existing destination under the retained splash for one frame.
      // AppShell receives pending links only after intro and bootstrap finish.
      _destination ??= widget.resolveNext?.call() ?? widget.nextScreen!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_coordinator.claimDestination()) {
          _destinationScheduled = false;
          return;
        }
        setState(() => _showDestination = true);
        _ticker.stop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_finishHandoff());
        });
      });
    }
  }

  Future<void> _finishHandoff() async {
    // Keep the popup at zero while the native texture is torn down and the
    // newly mounted feed finishes its first layout and paint.
    await _coordinator.releaseVideo();
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _welcomeReady = true;
    if (widget.config.diagnostics) {
      debugPrint('[stadium-splash] destination_ready_after_video_cleanup');
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _destinationVisible.value =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  void _releaseLaunch() {
    if (_launchReleased) return;
    _launchReleased = true;
    widget.releaseNativeLaunch?.call();
  }

  Future<void> _releaseNativeCover() async {
    if (_nativeHandoffStarted || !mounted) return;
    _nativeHandoffStarted = true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel('highlanders/splash').invokeMethod<void>(
          'releaseLaunchImage',
          {'durationMs': widget.config.nativeHandoffDuration.inMilliseconds},
        );
      }
    } on MissingPluginException {
      // Other hosts can paint the Flutter still without a native image overlay.
    } on PlatformException catch (error) {
      debugPrint('[stadium-splash] native_handoff_failed ${error.code}');
    }
    if (mounted) _coordinator.markNativeHandoffReady();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_showDestination) {
      _destinationVisible.value =
          _welcomeReady && state == AppLifecycleState.resumed;
      return;
    }
    final active = state == AppLifecycleState.resumed;
    _coordinator.setActive(active);
    if (active && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  Widget _image(int index) => Image(
    image: _providers[index],
    width: StadiumSplashConfig.sourceSize.width,
    height: StadiumSplashConfig.sourceSize.height,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, error, stack) =>
        const ColoredBox(color: StadiumSplashConfig.background),
  );

  Widget _media() => ClipRect(
    child: SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox.fromSize(
          size: StadiumSplashConfig.sourceSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A real mounted texture, painted at full opacity behind stills.
              if (_coordinator.videoPrepared) _coordinator.video.buildSurface(),
              if (_firstReady && !_coordinator.showVideo) ...[
                _image(_coordinator.stage == 0 ? 0 : _coordinator.stage - 1),
                if (_coordinator.stage > 0)
                  Opacity(
                    opacity: _coordinator.stillOpacity,
                    child: _image(_coordinator.stage),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_destination != null &&
            (_showDestination || _coordinator.canShowDestination))
          Positioned.fill(
            key: const ValueKey('startup-destination'),
            child: StartupVisibility(
              visible: _destinationVisible,
              child: _destination!,
            ),
          ),
        if (!_showDestination)
          Positioned.fill(
            key: const ValueKey('startup-splash'),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.black,
                systemNavigationBarIconBrightness: Brightness.light,
                systemStatusBarContrastEnforced: false,
                systemNavigationBarContrastEnforced: false,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: StadiumSplashConfig.background,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _media(),
                          if (_coordinator.introFinished &&
                              !_coordinator.bootstrapReady)
                            Material(
                              color: const Color(0x99160B09),
                              child: Center(
                                child: _coordinator.bootstrapError != null
                                    ? IconButton(
                                        key: const ValueKey(
                                          'splash-bootstrap-retry',
                                        ),
                                        tooltip: 'Retry loading app',
                                        color: Colors.white,
                                        onPressed: widget.retryBootstrap == null
                                            ? null
                                            : _coordinator.retry,
                                        icon: const Icon(Icons.refresh_rounded),
                                      )
                                    : const StartupLoader(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _coordinator.removeListener(_changed);
    _coordinator.dispose();
    _destinationVisible.dispose();
    _releaseLaunch();
    super.dispose();
  }
}
