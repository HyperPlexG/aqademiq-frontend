import AVFoundation
import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Prism (flutter_soloud) leaves the AVAudioSession untouched; the
    // playback category (with the `audio` UIBackgroundMode) is what keeps the
    // soundscape running when the phone locks. mixWithOthers so Prism never
    // interrupts the user's own music or podcasts.
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true)

    // Ask iOS for an APNs token at launch. FlutterFire's automatic registration
    // isn't firing under the implicit-engine AppDelegate lifecycle, so the token
    // callback below never ran and the device never registered (no iOS rows in
    // device_profiles → every push 400s "no registered device"). This is the
    // missing trigger; the token then flows to Firebase in the callback below.
    // (Independent of notification permission — the token is issued regardless;
    // permission only gates whether banners display.)
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Drives the lock screen, the Island and the widgets. Held for the life of
  /// the app because a focus session outlives any screen.
  private var ambient: AmbientPlugin?

  /// The 23 haptic patterns. Held for the life of the app because it owns a
  /// `CHHapticEngine`, and starting one per haptic would add latency to the
  /// very thing that has to feel immediate.
  private var haptics: HapticsPlugin?

  /// Calendar import and Reminder import — read-only EventKit access.
  private var deviceImport: DeviceImportPlugin?

  /// App freeze — Screen Time shields, Apple's app picker, and the schedule
  /// that keeps a frost running while Aqademiq is closed. Held for the life of
  /// the app because it also watches for the foreground, to hand Dart the thaw
  /// requests the shield queued meanwhile.
  private var appFreeze: AppFreezePlugin?

  /// Screenshots, for the weekly report's "Screenshotting?" banner. Held for
  /// the life of the app because it owns the notification observer.
  private var screenshot: ScreenshotPlugin?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    ambient = AmbientPlugin(messenger: messenger)
    if let url = pendingAmbientURL {
      pendingAmbientURL = nil
      ambient?.handle(url: url)
    }
    haptics = HapticsPlugin(messenger: messenger)
    deviceImport = DeviceImportPlugin(messenger: messenger)
    appFreeze = AppFreezePlugin(messenger: messenger)
    screenshot = ScreenshotPlugin(messenger: messenger)
  }

  /// A Freeze taken on the lock screen runs in the extension, which cannot
  /// reach the session itself — it parks the press in the shared container.
  /// This is where the app picks it up, so the press lands rather than being
  /// quietly lost when the student opens the app again.
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    ambient?.drainPendingAction()
  }

  /// A tapped widget arrives here as `aqademiq://…`.
  ///
  /// Anything else — Google Sign-In's reversed client id shares this callback —
  /// falls through to `super` untouched.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if handleAmbientURL(url) { return true }
    return super.application(app, open: url, options: options)
  }

  /// The ambient URL handler on its own. False for anything that is not ours,
  /// so the caller can pass it on. (`FlutterSceneDelegate` forwards a scene's
  /// opened URLs here; if a device ever shows widget taps not routing under
  /// the scene lifecycle, `SceneDelegate.scene(_:openURLContexts:)` is the
  /// place to call this from — verify the override against Flutter's header.)
  @discardableResult
  func handleAmbientURL(_ url: URL) -> Bool {
    guard let ambient = ambient else {
      // The engine (and so the plugin) is not up yet. Ours is held until it
      // is, rather than dropped; anything else goes back to the caller.
      guard url.scheme == "aqademiq" else { return false }
      pendingAmbientURL = url
      return true
    }
    return ambient.handle(url: url)
  }

  /// A widget's link that arrived before `ambient` existed.
  private var pendingAmbientURL: URL?

  // Hand the APNs device token to Firebase Messaging explicitly. Under the new
  // implicit-engine AppDelegate lifecycle, Firebase's swizzled hook doesn't
  // reliably fire, so the FCM SDK was left without an APNs token on iOS:
  // getAPNSToken()/getToken() returned null and the device never registered with
  // the backend (device_profiles had zero iOS rows), so every push — including
  // the test — silently dropped. Setting it here is safe whether or not
  // swizzling also runs (same token), and `super` still forwards to plugins.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Guard: Messaging needs a configured FirebaseApp. Dart's
    // Firebase.initializeApp() runs in main() and normally finishes before the
    // APNs token arrives, but guard so an early token can never crash the app.
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
