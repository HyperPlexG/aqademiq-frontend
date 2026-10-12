import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process alive while a focus session runs with the screen
/// off, so Prism audio and the client-side session timer keep going.
///
/// * **Android** — nothing to do here any more. `AmbientSessionService` is a
///   `mediaPlayback` foreground service for the whole session, which holds the
///   process up *and* owns the session card. Starting this one as well would
///   put a second notification in the shade for a single session, since Android
///   requires every foreground service to post its own.
/// * **iOS** — nothing to do here either: the `audio` `UIBackgroundMode` plus
///   the playback `AVAudioSession` category (set in `AppDelegate.swift`) keep
///   the app running while the soundscape plays.
/// * **Web/desktop** — no-op.
///
/// Kept as a seam rather than deleted: the platform channel is best-effort, so
/// this is where a fallback keepalive would go if the ambient service ever
/// turns out not to be reachable on some device.
class FocusKeepaliveService {
  FocusKeepaliveService._();

  static final FocusKeepaliveService instance = FocusKeepaliveService._();

  bool _running = false;

  /// No platform still needs the separate keepalive service.
  bool get _supported => false;

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
