import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process alive while a focus session runs with the screen
/// off, so Prism audio and the client-side session timer keep going.
///
/// * **Android** — a `mediaPlayback` foreground service with a quiet
///   persistent notification (declared in `AndroidManifest.xml`).
/// * **iOS** — nothing to do here: the `audio` `UIBackgroundMode` plus the
///   playback `AVAudioSession` category (set in `AppDelegate.swift`) keep the
///   app running while the soundscape plays.
/// * **Web/desktop** — no-op.
class FocusKeepaliveService {
  FocusKeepaliveService._();

  static final FocusKeepaliveService instance = FocusKeepaliveService._();

  bool _running = false;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts the foreground service (call when a focus session begins).
  Future<void> start() async {
    if (!_supported || _running) return;
    _running = true;
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'aqademiq_focus_session',
          channelName: 'Focus sessions',
          channelDescription:
              'Keeps your focus session and Prism audio running while the '
              'screen is off.',
        ),
        iosNotificationOptions:
            const IOSNotificationOptions(showNotification: false),
        foregroundTaskOptions: ForegroundTaskOptions(
          // Pure keepalive: no periodic Dart callback work.
          eventAction: ForegroundTaskEventAction.nothing(),
        ),
      );
      // Android 13+ hides the service notification without this permission;
      // the service itself still runs either way, so a denial is fine.
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission == NotificationPermission.denied) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.mediaPlayback],
        notificationTitle: 'Focus session in progress',
        notificationText: 'Prism keeps playing while your screen is off.',
      );
    } on Exception catch (e) {
      _running = false;
      debugPrint('Focus keepalive: could not start foreground service: $e');
    }
  }

  /// Stops the foreground service (call when the session ends).
  Future<void> stop() async {
    if (!_supported || !_running) return;
    _running = false;
    try {
      await FlutterForegroundTask.stopService();
    } on Exception catch (e) {
      debugPrint('Focus keepalive: could not stop foreground service: $e');
    }
  }
}
