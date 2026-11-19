import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:Highlanders/shared/widgets/media/app_video_player.dart';
import 'package:Highlanders/features/gallery/screens/gallery_screen.dart';
import 'package:Highlanders/features/gallery/data/gallery_repository.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  Size videoSize = const Size(1080, 1920);
  final events = <int, StreamController<VideoEvent>>{};
  final positions = <int, Duration>{};
  final playing = <int, bool>{};
  final volumes = <int, double>{};
  final disposed = <int>[];
  final sources = <String>[];
  int nextId = 1;

  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    final id = nextId++;
    events[id] = StreamController<VideoEvent>.broadcast();
    positions[id] = Duration.zero;
    sources.add(options.dataSource.uri!);
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(
      () => events[playerId]!.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 60),
          size: videoSize,
        ),
      ),
    );
    return events[playerId]!.stream;
  }

  @override
  Future<void> play(int playerId) async {
    playing[playerId] = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing[playerId] = false;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => positions[playerId]!;
  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes[playerId] = volume;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await events[playerId]!.close();
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => ColoredBox(
    key: ValueKey('native-video-${options.playerId}'),
    color: Colors.black,
  );
}

void main() {
  late FakeVideoPlatform platform;
  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  Future<void> open(
    WidgetTester tester, {
    bool autoPlay = false,
    String source = '/uploads/reel.mp4',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: AppVideoPlayer(source: source, autoPlay: autoPlay),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }

  testWidgets(
    'portrait and landscape video metadata determine the actual player ratio',
    (tester) async {
      await open(tester);
      final aspect = find.byKey(const ValueKey('app-video-aspect'));
      expect(
        tester.widget<AspectRatio>(aspect).aspectRatio,
        closeTo(9 / 16, .001),
      );
      final size = tester.getSize(aspect);
      expect(size.width / size.height, closeTo(9 / 16, .001));
      await close(tester);
      platform.videoSize = const Size(1920, 1080);
      await open(tester);
      expect(
        tester.widget<AspectRatio>(aspect).aspectRatio,
        closeTo(16 / 9, .001),
      );
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets('play pause, mute and unmute control native playback', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('video-play-pause')));
    await tester.pump();
    expect(platform.playing[1], true);
    await tester.tap(find.byKey(const ValueKey('video-play-pause')));
    await tester.pump();
    expect(platform.playing[1], false);
    await tester.tap(find.byKey(const ValueKey('video-mute')));
    await tester.pump();
    expect(platform.volumes[1], 0);
    expect(find.byTooltip('Unmute'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('video-mute')));
    await tester.pump();
    expect(platform.volumes[1], 1);
    await close(tester);
  });

  testWidgets(
    'ten second seeking clamps to the beginning and end; replay restarts',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('video-back-10')));
      await tester.pump();
      expect(platform.positions[1], Duration.zero);
      await tester.tap(find.byKey(const ValueKey('video-forward-10')));
      await tester.pump();
      expect(platform.positions[1], const Duration(seconds: 10));
      for (var n = 0; n < 7; n++) {
        await tester.tap(find.byKey(const ValueKey('video-forward-10')));
        await tester.pump();
      }
      expect(platform.positions[1], const Duration(seconds: 60));
      expect(find.byTooltip('Replay'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('video-play-pause')));
      await tester.pump();
      expect(platform.positions[1], Duration.zero);
      expect(platform.playing[1], true);
      await close(tester);
    },
  );

  testWidgets('seek bar scrubbing changes the position and time display', (
    tester,
  ) async {
    await open(tester);
    final finder = find.byKey(const ValueKey('video-seek'));
    final slider = tester.widget<Slider>(finder);
    slider.onChangeStart!(30000);
    slider.onChanged!(30000);
    slider.onChangeEnd!(30000);
    await tester.pump();
    expect(platform.positions[1], const Duration(seconds: 30));
    expect(find.text('0:30 / 1:00'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'controls hide during playback, return on tap and pause in background',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await open(tester, autoPlay: true);
      expect(platform.playing[1], true);
      await tester.pump(const Duration(seconds: 4));
      final opacity = find.ancestor(
        of: find.byKey(const ValueKey('video-play-pause')),
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
      await tester.tap(
        find.byKey(const ValueKey('video-surface')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(platform.playing[1], false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await close(tester);
      expect(platform.disposed, contains(1));
    },
  );

  testWidgets('changing video source releases the previous controller', (
    tester,
  ) async {
    await open(tester);
    await open(tester, source: '/uploads/another.mp4');
    expect(platform.disposed, contains(1));
    expect(platform.sources.last, endsWith('/uploads/another.mp4'));
    expect(find.byKey(const ValueKey('native-video-2')), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'fullscreen keeps one controller, playback position and restores system UI',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('video-forward-10')));
      await tester.pump();
      expect(find.byKey(const ValueKey('video-fullscreen')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('video-landscape')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('video-fullscreen-page')),
        findsOneWidget,
      );
      expect(platform.sources.length, 1);
      expect(platform.positions[1], const Duration(seconds: 10));
      await tester.tap(find.byKey(const ValueKey('video-play-pause')));
      await tester.pump();
      expect(platform.playing[1], true);
      await tester.tap(find.byKey(const ValueKey('video-landscape')));
      await tester.pumpAndSettle();
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        ['DeviceOrientation.portraitUp'],
      );
      await tester.tap(find.byKey(const ValueKey('video-landscape')));
      await tester.pumpAndSettle();
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      );
      await tester.tap(find.byKey(const ValueKey('video-fullscreen-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('video-fullscreen-page')), findsNothing);
      expect(platform.sources.length, 1);
      expect(platform.playing[1], true);
      expect(platform.positions[1], const Duration(seconds: 10));
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        defaultTargetPlatform == TargetPlatform.iOS
            ? ['DeviceOrientation.portraitUp']
            : isEmpty,
      );
      await close(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'landscape shortcut enters fullscreen and system back leaves it paused',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('video-landscape')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('video-fullscreen-page')),
        findsOneWidget,
      );
      expect(platform.playing[1], false);
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('video-fullscreen-page')), findsNothing);
      expect(platform.playing[1], false);
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        defaultTargetPlatform == TargetPlatform.iOS
            ? ['DeviceOrientation.portraitUp']
            : isEmpty,
      );
      await close(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('gallery opens in full view with the video title and no popup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGalleryVideoPopup(
                context,
                const GalleryItem(
                  id: 'sample',
                  title: 'Portrait Reel',
                  tagline: 'Video',
                  thumbnail: '',
                  type: 'videos',
                  videoUrl: '/uploads/reel.mp4',
                ),
              ),
              child: const Text('Open gallery video'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open gallery video'));
    await tester.pumpAndSettle();
    final aspect = find.byKey(const ValueKey('app-video-aspect'));
    final size = tester.getSize(aspect);
    expect(size.height, greaterThan(size.width));
    expect(
      find.byKey(const ValueKey('gallery-video-fullscreen')),
      findsOneWidget,
    );
    expect(size.width, closeTo(390, 1));
    expect(size.height, closeTo(844, 1));
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Portrait Reel'), findsOneWidget);
    expect(find.byKey(const ValueKey('video-play-pause')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
