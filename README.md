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
flutter pub get
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

Notifications currently depend on the app's socket connection. iOS can suspend
that connection in the background; reliable delivery while suspended or terminated
requires an APNs push integration with the backend, which is not included here.

Test folders, generated build outputs, Pods and local Xcode configuration are
ignored. Do not commit signing certificates or provisioning profiles.
