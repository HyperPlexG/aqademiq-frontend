import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The one Android channel every Aqademiq reminder posts to.
///
/// The backend names this same id when it sends an FCM push
/// (`android.notification.channel_id` in `supabase/functions/_shared/push.ts`),
/// so locally-scheduled and server-delivered reminders share one row in the
/// system notification settings instead of looking like two different features.
const androidReminderChannel = AndroidNotificationChannel(
  'aqademiq_default',
  'Reminders',
  description: 'Task reminders and check-ins',
  importance: Importance.high,
);

/// How locally-scheduled reminders are presented.
const reminderDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'aqademiq_default',
    'Reminders',
    channelDescription: 'Task reminders and check-ins',
    importance: Importance.high,
    priority: Priority.high,
  ),
  // Matches the `interruption-level` the backend sets on its APNs payload:
  // time-sensitive breaks through Focus and Scheduled Summary, which were
  // otherwise batching reminders by up to ~20 minutes. Requires the
  // Time-Sensitive Notifications entitlement; without it iOS quietly falls
  // back to the normal level, so it is safe either way.
  iOS: DarwinNotificationDetails(
    interruptionLevel: InterruptionLevel.timeSensitive,
  ),
);

/// Process-wide owner of the `flutter_local_notifications` plugin.
///
/// Both notification paths go through this single instance:
/// * [`push_service.dart`](push_service.dart) — displaying an FCM message that
///   arrived while the app was foregrounded.
/// * [`reminder_scheduler.dart`](reminder_scheduler.dart) — the client-side
///   reminder schedule.
///
/// Ownership is deliberately singular: `initialize()` is global state, so two
/// instances initialising with different settings silently leaves whichever ran
/// last in charge. Everything here is best-effort — under `flutter test` the
/// method channels don't exist, and a plugin failure must never take the app
/// down, so [ready] simply stays false and scheduling no-ops.
class LocalNotifications {
  LocalNotifications._();

  static final LocalNotifications instance = LocalNotifications._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initing;
  bool _ready = false;

  /// Whether the plugin initialised. False on web, in unit tests, and after any
  /// platform failure — callers should skip scheduling rather than throw.
  bool get ready => _ready;

  void Function(String payload)? _onTap;
  String? _bufferedTap;

  /// Idempotent. Loads the timezone database, points it at the device's own
  /// IANA zone, initialises the plugin and creates the Android channel.
  Future<void> ensureInitialized() => _initing ??= _init();

  Future<void> _init() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      // Schedules are computed in the device's zone, not UTC, so a reminder set
      // for 09:00 stays at 09:00 across a DST boundary or a flight.
      try {
        tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()),
        );
      } on Object {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested explicitly via [requestPermission] so the
          // answer is observable; asking here throws the result away.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) _handleTap(payload);
        },
      );

      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidReminderChannel);

      _ready = true;

      // A tap that cold-started the app doesn't reach the callback above.
      final launch = await plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          payload != null &&
          payload.isNotEmpty) {
        _handleTap(payload);
      }
    } on Object catch (e) {
      debugPrint('LocalNotifications: init failed — $e');
    }
  }

  /// Ask the OS for permission to post notifications. Safe to call repeatedly —
  /// after the first answer both platforms return the current status without
  /// re-prompting.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final granted = await plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      final granted = await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    } on Object catch (e) {
      debugPrint('LocalNotifications: permission request failed — $e');
      return false;
    }
  }

  /// Register the (single) handler for reminder taps. Any tap that arrived
  /// before the app was ready to route — a cold start from the notification
  /// tray — is replayed immediately.
  void setTapHandler(void Function(String payload) handler) {
    _onTap = handler;
    final buffered = _bufferedTap;
    if (buffered != null) {
      _bufferedTap = null;
      handler(buffered);
    }
  }

  void _handleTap(String payload) {
    final handler = _onTap;
    if (handler == null) {
      _bufferedTap = payload;
      return;
    }
    handler(payload);
  }
}
