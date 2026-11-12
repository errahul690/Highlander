import AVFoundation
import CryptoKit
import Flutter
import UIKit
import UniformTypeIdentifiers

/// Implements the same channels used by the Android host and shared Dart UI.
final class HighlandersPlatformBridge: NSObject, UIDocumentPickerDelegate {
  private let links: FlutterMethodChannel
  private let thumbnails: FlutterMethodChannel
  private let splash: FlutterMethodChannel
  private let workers: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "highlanders.video-posters"
    queue.maxConcurrentOperationCount = 2
    return queue
  }()
  private var initialLink: String?
  private var linksReady = false
  private var attachmentResult: FlutterResult?
  private let maximumAttachmentSize = 15 * 1024 * 1024

  init(messenger: FlutterBinaryMessenger) {
    links = FlutterMethodChannel(name: "highlanders/app_links", binaryMessenger: messenger)
    thumbnails = FlutterMethodChannel(name: "highlanders/video_thumbnail", binaryMessenger: messenger)
    splash = FlutterMethodChannel(name: "highlanders/splash", binaryMessenger: messenger)
    super.init()
    links.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    thumbnails.setMethodCallHandler { [weak self] call, result in
      guard call.method == "extract" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any] ?? [:]
      let source = arguments["source"] as? String ?? ""
      let local = arguments["local"] as? Bool ?? false
      self?.workers.addOperation {
        let path = Self.extractThumbnail(source: source, local: local)
        DispatchQueue.main.async { result(path) }
      }
    }
    // iOS uses LaunchScreen until Flutter draws its existing splash/skip UI.
    splash.setMethodCallHandler { call, result in
      switch call.method {
      case "hide", "setAllowSkip": result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func receive(_ url: URL) {
    guard url.scheme?.lowercased() == "highlanders", url.host == "post" else { return }
    if linksReady {
      links.invokeMethod("incomingLink", arguments: url.absoluteString)
    } else {
      initialLink = url.absoluteString
    }
  }

  private var presenter: UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var controller = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getInitialLink":
      linksReady = true
      result(initialLink)
      initialLink = nil
    case "openUrl":
      guard let text = arguments["url"] as? String,
            let url = URL(string: text),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            let host = url.host, !host.isEmpty else {
        result(FlutterError(code: "invalid_url", message: "Enter a valid website link", details: nil))
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened ? nil : FlutterError(code: "open_failed", message: "Could not open this link", details: nil))
      }
    case "sharePost":
      guard let presenter = presenter else {
        result(FlutterError(code: "share_failed", message: "Could not open share options", details: nil))
        return
      }
      let sheet = UIActivityViewController(
        activityItems: [arguments["text"] as? String ?? ""], applicationActivities: nil
      )
      // An anchor is required when presenting the share sheet on iPad.
      sheet.popoverPresentationController?.sourceView = presenter.view
      sheet.popoverPresentationController?.sourceRect = CGRect(
        x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0
      )
      sheet.popoverPresentationController?.permittedArrowDirections = []
      presenter.present(sheet, animated: true)
      result(nil)
    case "pickChatAttachment":
      guard attachmentResult == nil else {
        result(FlutterError(code: "picker_busy", message: "File picker is already open", details: nil))
        return
      }
      guard let presenter = presenter else {
        result(FlutterError(code: "pick_failed", message: "Could not open file picker", details: nil))
        return
      }
      let mimeTypes = [
        "image/jpeg", "image/png", "image/gif", "image/webp", "image/avif",
        "application/pdf", "text/plain", "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      ]
      let types = mimeTypes.compactMap { UTType(mimeType: $0) }
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
      picker.delegate = self
      picker.allowsMultipleSelection = false
      attachmentResult = result
      presenter.present(picker, animated: true)
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
    guard let url = urls.first else {
      attachmentResult = nil
      result(nil)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      var output: Any?
      do {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        guard (values.fileSize ?? 0) <= maximumAttachmentSize else {
          throw AttachmentError.tooLarge
        }
        let directory = try FileManager.default.url(
          for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("chat_attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        try FileManager.default.copyItem(at: url, to: target)
        let size = try target.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumAttachmentSize else {
          try? FileManager.default.removeItem(at: target)
          throw AttachmentError.tooLarge
        }
        output = [
          "path": target.path, "name": url.lastPathComponent,
          "type": values.contentType?.preferredMIMEType ?? "application/octet-stream", "size": size,
        ]
      } catch AttachmentError.tooLarge {
        output = FlutterError(code: "file_too_large", message: "Choose a file smaller than 15 MB", details: nil)
      } catch {
        output = FlutterError(code: "pick_failed", message: "Could not read this file", details: nil)
      }
      let response = output
      DispatchQueue.main.async {
        self.attachmentResult = nil
        result(response)
      }
    }
  }

  private enum AttachmentError: Error { case tooLarge }

  private static func extractThumbnail(source: String, local: Bool) -> String? {
    guard !source.isEmpty else { return nil }
    let url: URL
    var identity = source
    if local {
      url = URL(fileURLWithPath: source)
      guard let attributes = try? FileManager.default.attributesOfItem(atPath: source) else { return nil }
      identity += ":\(attributes[.size] ?? 0):\(attributes[.modificationDate] ?? "")"
    } else {
      guard let remote = URL(string: source),
            ["http", "https"].contains(remote.scheme?.lowercased() ?? ""),
            let host = remote.host, !host.isEmpty else { return nil }
      url = remote
    }
    do {
      let directory = try FileManager.default.url(
        for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
      ).appendingPathComponent("video-posters", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let digest = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
      let poster = directory.appendingPathComponent("\(digest).jpg")
      if FileManager.default.fileExists(atPath: poster.path) {
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: poster.path)
        return poster.path
      }
      // AVFoundation can fetch only the ranges needed for a remote video's frame.
      let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 640, height: 640)
      let timeout = DispatchWorkItem { generator.cancelAllCGImageGeneration() }
      DispatchQueue.global().asyncAfter(deadline: .now() + 25, execute: timeout)
      defer { timeout.cancel() }
      let frame = try generator.copyCGImage(at: .zero, actualTime: nil)
      guard let data = UIImage(cgImage: frame).jpegData(compressionQuality: 0.82) else { return nil }
      try data.write(to: poster, options: .atomic)
      let cached = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
      ).filter { $0.pathExtension == "jpg" }.sorted {
        let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return left > right
      }
      for old in cached.dropFirst(60) { try? FileManager.default.removeItem(at: old) }
      return poster.path
    } catch {
      // A missing poster must never prevent video playback.
      return nil
    }
  }
}
