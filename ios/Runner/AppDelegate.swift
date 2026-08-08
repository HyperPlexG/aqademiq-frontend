import AVFoundation
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

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
    Messaging.messaging().apnsToken = deviceToken
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
