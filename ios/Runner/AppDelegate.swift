import Flutter
import UIKit
import AVFoundation
import CryptoKit
import UniformTypeIdentifiers
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var linksChannel: FlutterMethodChannel?
  private var initialLink: String?
  private var initialLinkRequested = false
  private var attachmentResult: FlutterResult?
  private let thumbnailQueue = DispatchQueue(label: "highlanders.video-thumbnails")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let links = FlutterMethodChannel(name: "highlanders/app_links", binaryMessenger: messenger)
    linksChannel = links
    links.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      self.handleAppCall(call, result: result)
    }
    let thumbnails = FlutterMethodChannel(name: "highlanders/video_thumbnail", binaryMessenger: messenger)
    thumbnails.setMethodCallHandler { [weak self] call, result in
      guard call.method == "extract" else { result(FlutterMethodNotImplemented); return }
      self?.extractThumbnail(call.arguments as? [String: Any] ?? [:], result: result)
    }
    // The Flutter splash screen handles HTML, video and skip controls on iOS.
    let splash = FlutterMethodChannel(name: "highlanders/splash", binaryMessenger: messenger)
    splash.setMethodCallHandler { call, result in
      if call.method == "hide" || call.method == "setAllowSkip" {
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func receiveLink(_ url: URL) {
    guard url.scheme == "Highlanders", url.host == "post" else { return }
    if initialLinkRequested {
      linksChannel?.invokeMethod("incomingLink", arguments: url.absoluteString)
    } else {
      initialLink = url.absoluteString
    }
  }

  private var presentingController: UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  private func handleAppCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getInitialLink":
      initialLinkRequested = true
      result(initialLink)
      initialLink = nil
    case "openUrl":
      guard let raw = args["url"] as? String, let url = URL(string: raw),
            ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
            let host = url.host, !host.isEmpty else {
        result(FlutterError(code: "invalid_url", message: "Enter a valid website link", details: nil))
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened ? nil : FlutterError(code: "open_failed", message: "Could not open this link", details: nil))
      }
    case "sharePost":
      guard let controller = presentingController else {
        result(FlutterError(code: "share_failed", message: "Could not open share options", details: nil))
        return
      }
      let sheet = UIActivityViewController(activityItems: [args["text"] as? String ?? ""], applicationActivities: nil)
      if let popover = sheet.popoverPresentationController {
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }
      controller.present(sheet, animated: true) { result(nil) }
    case "pickChatAttachment":
      guard attachmentResult == nil else {
        result(FlutterError(code: "picker_busy", message: "File picker is already open", details: nil))
        return
      }
      guard let controller = presentingController else {
        result(FlutterError(code: "pick_failed", message: "Could not open file picker", details: nil))
        return
      }
      let types = ["jpg", "jpeg", "png", "gif", "webp", "avif", "pdf", "txt", "doc", "docx", "xls", "xlsx", "ppt", "pptx"]
        .compactMap { UTType(filenameExtension: $0) }
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
      picker.delegate = self
      picker.allowsMultipleSelection = false
      attachmentResult = result
      controller.present(picker, animated: true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = attachmentResult
    attachmentResult = nil
    result?(nil)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = attachmentResult else { return }
    attachmentResult = nil
    guard let url = urls.first else { result(nil); return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
      guard (values.fileSize ?? 0) <= 15 * 1024 * 1024 else {
        result(FlutterError(code: "file_too_large", message: "Choose a file smaller than 15 MB", details: nil))
        return
      }
      let cache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("chat_attachments", isDirectory: true)
      try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
      let target = cache.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
      try FileManager.default.copyItem(at: url, to: target)
      let size = try target.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= 15 * 1024 * 1024 else {
        try? FileManager.default.removeItem(at: target)
        result(FlutterError(code: "file_too_large", message: "Choose a file smaller than 15 MB", details: nil))
        return
      }
      result(["path": target.path, "name": url.lastPathComponent,
              "type": values.contentType?.preferredMIMEType ?? "application/octet-stream", "size": size])
    } catch {
      result(FlutterError(code: "pick_failed", message: "Could not read this file", details: nil))
    }
  }

  private func extractThumbnail(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let source = args["source"] as? String, !source.isEmpty else { result(nil); return }
    let local = args["local"] as? Bool ?? false
    guard let url = local ? URL(fileURLWithPath: source) : URL(string: source) else { result(nil); return }
    thumbnailQueue.async {
      do {
        let directory = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
          .appendingPathComponent("video_thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
        let target = directory.appendingPathComponent("\(digest).jpg")
        if !FileManager.default.fileExists(atPath: target.path) {
          let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
          generator.appliesPreferredTrackTransform = true
          generator.maximumSize = CGSize(width: 960, height: 960)
          let image = try generator.copyCGImage(at: .zero, actualTime: nil)
          guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else {
            DispatchQueue.main.async { result(nil) }
            return
          }
          try jpeg.write(to: target, options: .atomic)
        }
        DispatchQueue.main.async { result(target.path) }
      } catch {
        DispatchQueue.main.async { result(nil) }
      }
    }
  }
}
