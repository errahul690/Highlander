# Highlanders mobile

Flutter app for Android and iOS. Both platforms use the same Dart screens and API
configuration in `.env`.

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
