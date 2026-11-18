import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  var platformBridge: HighlandersPlatformBridge?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Preserve Flutter forwarding for local notifications. Messaging recognises
    // FlutterAppDelegate and keeps this delegate to avoid forwarding loops.
    UNUserNotificationCenter.current().delegate = self
    // UIScene registers plugins later; initialise the Messaging delegate hook
    // before didFinishLaunching returns, as required by Messaging 17+.
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    platformBridge = HighlandersPlatformBridge(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}
