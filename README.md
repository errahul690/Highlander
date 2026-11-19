# Highlanders mobile

Flutter app for Android and iOS. Both platforms use the same Dart screens and API
configuration in `.env`.

## Source layout

The app groups code by feature. `lib/main.dart` remains the Flutter entry point.

```text
lib/
  main.dart
  app/                  App shell and app-wide navigation
  core/
    media/              Shared downloads, media cache and thumbnails
    network/            Read recovery and realtime connection
    notifications/      Push delivery and notification routing
    session/            Signed-in session and secure storage
    theme/              Brand colours and app theme
  shared/
    branding/           Club identity helpers
    data/               Club data, cities and shared header configuration
    models/             Player, fixture and club-content models
    widgets/            Headers, navigation, avatars and reusable UI
  features/
    auth/               Login, OTP and account creation
    chat/               Messages, attachments and chat settings
    community/          Friends, follows, huddles and groups
    explore/            Explore configuration and cards
    feed/               Feed startup, banners, quick links and sections
    gallery/            Galleries and photo viewer
    grounds/            Grounds data, maps and venue screens
    matches/            Fixtures, results, live match and reports
    notifications/      Notifications screen
    polls/              Poll data and voting UI
    posts/              Post cards, reactions, comments, reposts and reels
    profile/            Profile screens, covers and editing
    search/             App search
    settings/           Settings screens and legal links
    splash/             Launch screen and bundled splash configuration
    squad/              Squad, player screens and squad presentation
    support/            Support hub data and care-chat widgets
    swoofi/             Swoofi screen
```

Within each feature, use `data/` for repositories, API clients and caches,
`screens/` for routes, and `widgets/` for feature-specific UI. Add `services/` or
`utils/` only when the feature needs them. Keep code in its owning feature;
move it into `shared/` when several features genuinely reuse it.

Use `package:Highlanders/...` imports for app code, including in local tests.
The package name is case-sensitive. Android/iOS native projects and asset paths
remain in their existing top-level folders.

## Android

```sh
flutter pub get
flutter run -d <android-device-id>
```

On Windows, `./run-android.ps1` also starts the configured Android emulator.

## iOS

Requires a Mac with Xcode, its command-line tools, the iOS simulator runtime,
Flutter and CocoaPods (for plugins that do not support Swift Package Manager).
The Xcode project targets iOS 15.0 or newer, with bundle identifier
`com.highlanders.highlanders`.

From this directory on the Mac:

```sh
cp .env.example .env
# Set API_BASE_URL to the HTTPS API reachable from the iPhone before building.
flutter pub get
cd ios
pod install
cd ..
flutter build ios --simulator
open ios/Runner.xcworkspace
```

In Xcode, select the **Runner** target and choose your Apple development team
under **Signing & Capabilities**. Use a unique bundle identifier if required by
your team. Then select an iPhone simulator or connected device and run the app.
You can also use `flutter run -d <ios-device-id>`.

For distribution after configuring signing:

```sh
flutter build ipa --release
```

The iOS integration includes photo/camera/microphone usage descriptions, Keychain
storage, local notification permission, the `highlanders://post/<id>` URL scheme,
native sharing, document attachments and cached video thumbnails. The startup
animation uses the existing Flutter splash screen after the native launch screen.
The production HTTPS API is configured in `.env`; point it to a server reachable
from the iPhone when developing locally.

Firebase Messaging and APNs registration are integrated. Confirm that
`ios/Runner/GoogleService-Info.plist` matches the signed bundle identifier, that
Push Notifications and Background Modes > Remote notifications are enabled, and
that the Firebase project has the team's APNs credentials. Verify push delivery
and notification taps on a signed physical iPhone, including background and
terminated states.

### iOS developer handoff (19 November 2026)

- Use a Flutter toolchain with Dart 3.13 or newer (the current local toolchain is
  Flutter 3.47.6 / Dart 3.13.5). The deployment target remains iOS 15.0.
- Pull the complete repository, including `third_party/video_player`,
  `third_party/video_player_android` and `third_party/video_player_avfoundation`.
  These local dependency overrides include the native first-frame readiness
  channel used by the stadium splash. Keep the overrides and run `pod install`
  after `flutter pub get`.
- `.env` is ignored and must be created on the Mac. Use the production HTTPS API
  for release builds; the example's LAN address is for local development.
  Optional backup servers can be configured with `API_FALLBACK_URL` or an ordered
  `API_BASE_URL=https://primary.example/api || https://backup.example/api` list.
  Startup selects a server using `GET /api/common/health`, expecting HTTP 200
  with `success: true` and `service: common`. Each probe has a three-second
  timeout. OTP and other writes are sent only to the selected server.
- Retain the native stadium launch asset/storyboard, the AppDelegate implicit
  engine registration and Firebase Messaging delegate setup. On a physical
  iPhone, verify cold launch, still-to-video transition, background/resume and
  navigation after the splash completes.
- Shared Dart updates include gallery/highlights fullscreen video controls,
  Instagram reel handling, Create Post keyboard/layout behavior and API fallback
  selection. Verify playback, seeking, mute, fullscreen exit, gallery filters,
  Create Post with the keyboard, and first-open OTP verification on iPhone.
- Run `flutter analyze`, `flutter build ios --release --no-codesign`, then a
  signed device build. Configure the team's signing before
  `flutter build ipa --release`, using a new build number for TestFlight.
  iOS compilation and physical iPhone playback have not been verified on this
  Windows development machine.

Test folders, generated build outputs, Pods and local Xcode configuration are
ignored. Do not commit signing certificates or provisioning profiles.
