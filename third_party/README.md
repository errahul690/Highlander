# Video renderer extension

These are repository-local copies of the already installed Flutter packages. Their upstream BSD licenses and author lists are retained.

| Package | Upstream version | Local change |
| --- | --- | --- |
| `video_player` | 2.14.1 | Public `VideoPlayerController.nativePlayerIdentifier` and `nativePlaybackCompleted` getters |
| `video_player_android` | 2.12.2 | Per-player readiness flag driven by Media3 `onRenderedFirstFrame`, reset on surface cleanup, queried through the plugin |
| `video_player_avfoundation` | 2.12.1 | Atomic `firstFrameCopied` flag set when the actual Flutter texture returns a populated pixel buffer, queried through the plugin |

`pubspec.yaml` overrides all three packages to these folders. The global Pub cache is untouched. Dart sources, native build sources, package manifests and licenses are copied from those versions. Native upstream tests stay local and are excluded from version control.

## Extension contract

`nativePlaybackCompleted` becomes true only for the platform's completed event.
Position polling or seeking to the reported duration does not satisfy it.
Playing again or seeking before the end resets it. The splash uses this signal
to wait for actual playback completion before revealing the welcome.

The plugin registers `highlanders/video_frame`. `isFirstFrameReady` accepts a map containing the controller's integer `playerId` and returns a boolean for that exact player. Unknown players return false. A disposed Android player returns false. iOS removes disposed players from its registry. The channel is removed when the engine detaches.

Android observes Media3's renderer attached to the real `SurfaceProducer`. Surface cleanup clears readiness. Media3 emits another event when the replacement surface receives its first frame. [Media3 listener reference](https://developer.android.com/reference/androidx/media3/common/Player.Listener)

iOS observes the actual `FVPTextureBasedVideoPlayer.copyPixelBuffer` path. Its hidden workaround `AVPlayerLayer` supplies no readiness evidence. The atomic property transfers readiness from the raster thread to the main-thread plugin query. [Flutter texture reference](https://api.flutter.dev/ios-embedder/protocol_flutter_texture-p.html)

The app samples this signal at a configurable 32 ms interval while preparing. Sampling latency can extend the final still. A missing channel or signal causes the decorative video to be skipped through the configured failure gate. Playback remains paused at time zero throughout preparation. Final display scanout still requires visual device verification.

## Maintaining the copies

When intentionally updating a package, compare the upstream version with its local copy. Reapply the getter, Android player flag and surface reset, iOS atomic pixel-buffer flag, and each plugin's channel registration and detach cleanup. Keep the three versions compatible. Run the adapter and coordinator tests, compile Android and iOS, then inspect a profile or release capture around the still-to-video boundary.

The extension changes these upstream source files.

The bundled stadium MP4 additionally uses `texture/StadiumSurfaceProducer.java`, an adapter for the engine-managed `SurfaceTextureEntry`. Flutter's ImageReader surface reports that it does not handle crop metadata automatically. On the tested Android 16 decoder, the original texture path shifted the stadium goal upward by about 12 screen pixels when video replaced the still. SurfaceTexture's decoder crop matrix aligns the opening video frame with the PNG without an asset transform or a fixed pixel correction. The selection is scoped to the exact stadium asset URI. The surface is retained until player disposal, and its registry entry and Surface are released together. Recheck crop handling and lifecycle behavior when upgrading Flutter.

- `video_player/lib/video_player.dart`
- `video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/VideoPlayer.java`
- `video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/VideoPlayerPlugin.java`
- `video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/texture/TextureVideoPlayer.java`
- `video_player_avfoundation/darwin/video_player_avfoundation/Sources/video_player_avfoundation/VideoPlayerPlugin.swift`
- `video_player_avfoundation/darwin/video_player_avfoundation/Sources/video_player_avfoundation_objc/FVPTextureBasedVideoPlayer.m`
- `video_player_avfoundation/darwin/video_player_avfoundation/Sources/video_player_avfoundation_objc/include/video_player_avfoundation_objc/FVPTextureBasedVideoPlayer.h`
