import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../core/env/env.dart';
import '../core/network/dio_client.dart';
import '../data/auth/auth_repository.dart';

/// FCM background/terminated handler — must be a top-level, annotated function so
/// the engine can invoke it in a fresh isolate. The OS renders the `notification`
/// payload itself, so display needs nothing here; this exists to satisfy the API
/// and as a hook for future data-only messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Android channel that foreground reminders post to (Android 8+ requires one).
const _channel = AndroidNotificationChannel(
  'aqademiq_default',
  'Reminders',
  description: 'Task reminders and check-ins',
  importance: Importance.high,
);

/// Push notifications: permission, FCM token, device registration (`POST /devices`),
/// token-refresh re-registration, and foreground display via local notifications.
///
/// Kept alive by being watched at the app root (app.dart). It listens to auth
/// and registers this device once a session exists (guest or account) — the
/// `/devices` endpoint needs a bearer token. No-op under mocks: mock builds never
/// initialize Firebase, so both platforms simply do nothing.
///
/// Both platforms use FCM (iOS delivers through Firebase → APNs), so the token is
/// always an FCM token and the device registers with `token_provider: 'fcm'`.
// Watched at the app root (app.dart), but the lint can't trace Riverpod's
// `ref.watch` indirection, so it wrongly reports this as unreachable.
// ignore: unreachable_from_main
final pushServiceProvider = Provider<void>((ref) {
  if (Env.useMocks || !Env.hasSupabase) return;
  final service = _PushService(ref);
  ref.listen(authStateProvider, (_, next) {
    if (next.value != null) unawaited(service.ensureRegistered());
  }, fireImmediately: true);
});

class _PushService {
  _PushService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _inited = false;
  bool _registered = false;
  String _permission = 'granted';

  Dio get _dio => _ref.read(dioProvider);

  /// Idempotent: initialise messaging + local notifications once, then register
  /// the device with the backend. Best-effort — never throws to the caller.
  Future<void> ensureRegistered() async {
    try {
      await _init();
      await _register();
    } on Object catch (e) {
      debugPrint('PushService.ensureRegistered failed: $e');
    }
  }

  Future<void> _init() async {
    if (_inited) return;
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission();
    _permission = switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => 'granted',
      AuthorizationStatus.provisional => 'provisional',
      _ => 'denied',
    };

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings);
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Show a banner for messages that arrive while the app is foregrounded.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showForeground);
    messaging.onTokenRefresh.listen((_) => unawaited(_register(force: true)));

    _inited = true;
  }

  Future<void> _register({bool force = false}) async {
    if (_registered && !force) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    await _dio.post<void>(
      '/devices',
      data: <String, dynamic>{
        'push_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'token_provider': 'fcm',
        'timezone': await _timezone(),
        'permission': _permission,
      },
    );
    _registered = true;
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    unawaited(_local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'aqademiq_default',
          'Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    ));
  }

  /// The device's IANA zone (e.g. `Asia/Dubai`) — the backend validates it and
  /// fires reminders on local wall-clock. Falls back to UTC if unavailable.
  Future<String> _timezone() async {
    try {
      return await FlutterTimezone.getLocalTimezone();
    } on Object {
      return 'UTC';
    }
  }
}
