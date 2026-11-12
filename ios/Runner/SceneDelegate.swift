import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var bridge: HighlandersPlatformBridge? {
    (UIApplication.shared.delegate as? AppDelegate)?.platformBridge
  }

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let url = connectionOptions.urlContexts.first?.url {
      bridge?.receive(url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    if let url = URLContexts.first?.url {
      bridge?.receive(url)
    }
  }
}
