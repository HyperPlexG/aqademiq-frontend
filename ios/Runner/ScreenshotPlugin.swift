import Flutter
import UIKit

/// Tells Dart when the student takes a screenshot, for the weekly report's
/// "Screenshotting?" banner (v11 `core-screenshot`,
/// lib/features/report/report_screenshots.dart).
///
/// One call, `screenshotTaken`, with no arguments: iOS says a screenshot
/// happened and nothing about what is in it, and nothing here asks. Dart only
/// listens while the report is on screen, so a screenshot anywhere else goes
/// unanswered — the observer is cheap enough to hold for the life of the app.
final class ScreenshotPlugin {
  static let channelName = "aqademiq/screenshot"

  private let channel: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    observer = NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.channel.invokeMethod("screenshotTaken", arguments: nil)
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}
